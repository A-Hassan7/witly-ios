//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Foundation
import UIKit

protocol WitlyOnboardingFlowCoordinatorDelegate: AnyObject {
    /// Onboarding is complete and the provisioned Matrix session has been restored.
    func witlyOnboardingFlowCoordinator(didLoginWithSession userSession: UserSessionProtocol)
}

struct WitlyOnboardingFlowCoordinatorParameters {
    let navigationRootCoordinator: NavigationRootCoordinator
    let presentationAnchor: UIWindow
    let userSessionStore: UserSessionStoreProtocol
    let appSettings: AppSettings
    let appHooks: AppHooks
    let userIndicatorController: UserIndicatorControllerProtocol
}

/// Drives Witly's onboarding — carousel → auth → connect — replacing Element's own
/// `AuthenticationFlowCoordinator` at the seam in `AppCoordinator.startAuthentication()`.
///
/// Per product decision there's no Wit-selection step and no unconditional "loading" screen:
/// provisioning is kicked off in the background as soon as auth succeeds, and a loading indicator
/// is only shown if it hasn't finished by the time the user reaches the end of the flow.
final class WitlyOnboardingFlowCoordinator: FlowCoordinatorProtocol {
    weak var delegate: WitlyOnboardingFlowCoordinatorDelegate?
    
    private let parameters: WitlyOnboardingFlowCoordinatorParameters
    private let navigationStackCoordinator: NavigationStackCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    private let witlySession = WitlySession()
    private lazy var apiClient = AGChatAPIClient(session: witlySession)
    private lazy var provisioning = WitlyProvisioning(api: apiClient)
    private lazy var sessionRestorer = WitlySessionRestorer(userSessionStore: parameters.userSessionStore,
                                                            appSettings: parameters.appSettings,
                                                            appHooks: parameters.appHooks)
    
    /// Kicked off as soon as auth succeeds so it can run in parallel with the connect step.
    private var provisioningTask: Task<WitlyMatrixCredentials, Error>?
    
    init(parameters: WitlyOnboardingFlowCoordinatorParameters) {
        self.parameters = parameters
        navigationStackCoordinator = NavigationStackCoordinator()
    }
    
    func start(animated: Bool) {
        presentIntro()
        parameters.navigationRootCoordinator.setRootCoordinator(navigationStackCoordinator, animated: animated)
    }
    
    func handleAppRoute(_ appRoute: AppRoute, animated: Bool) {
        // Witly onboarding doesn't handle deep links (QR login, provisioning links, etc).
    }
    
    func clearRoute(animated: Bool) { }
    
    // MARK: - Steps
    
    private func presentIntro() {
        let coordinator = WitlyOnboardingIntroCoordinator()
        coordinator.actionsPublisher.sink { [weak self] action in
            switch action {
            case .getStarted, .signIn:
                self?.presentAuth()
            }
        }
        .store(in: &cancellables)
        
        navigationStackCoordinator.setRootCoordinator(coordinator)
    }
    
    private func presentAuth() {
        let authParameters = WitlyOnboardingAuthCoordinatorParameters(witlySession: witlySession,
                                                                      presentationAnchor: parameters.presentationAnchor)
        let coordinator = WitlyOnboardingAuthCoordinator(parameters: authParameters)
        coordinator.actionsPublisher.sink { [weak self] action in
            switch action {
            case .authenticated:
                self?.beginProvisioning()
                self?.presentConnect()
            }
        }
        .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    private func presentConnect() {
        let coordinator = WitlyOnboardingConnectCoordinator(parameters: .init(witlySession: witlySession))
        coordinator.actionsPublisher.sink { [weak self] action in
            switch action {
            case .finished:
                self?.finishOnboarding()
            }
        }
        .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    // MARK: - Provisioning & session restore
    
    /// Fires as soon as auth succeeds so it's likely already `READY` by the time the user finishes
    /// the connect step, avoiding any loading UI in the common case.
    private func beginProvisioning() {
        provisioningTask = Task {
            try await provisioning.provision()
        }
    }
    
    private func finishOnboarding() {
        Task {
            do {
                let credentials = try await awaitProvisioning()
                stopHoldingIndicator()
                
                switch await sessionRestorer.restore(credentials: credentials) {
                case .success(let userSession):
                    delegate?.witlyOnboardingFlowCoordinator(didLoginWithSession: userSession)
                case .failure(let error):
                    WitlyLog.error("Failed restoring provisioned session: \(error)")
                    showFailureIndicator()
                }
            } catch {
                WitlyLog.error("Provisioning failed: \(error)")
                stopHoldingIndicator()
                showFailureIndicator()
            }
        }
    }
    
    /// Awaits the in-flight provisioning task, only surfacing a loading indicator if it's still
    /// running after a short grace period (per the "no unconditional loading screen" decision).
    private func awaitProvisioning() async throws -> WitlyMatrixCredentials {
        guard let provisioningTask else { throw WitlyProvisioningError.missingCredentials }
        
        enum RaceResult {
            case credentials(WitlyMatrixCredentials)
            case stillWaiting
        }
        
        return try await withThrowingTaskGroup(of: RaceResult.self) { group in
            group.addTask { try await .credentials(provisioningTask.value) }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(400))
                return .stillWaiting
            }
            
            var credentials: WitlyMatrixCredentials?
            while credentials == nil, let next = try await group.next() {
                switch next {
                case .credentials(let value):
                    credentials = value
                case .stillWaiting:
                    startHoldingIndicator()
                }
            }
            group.cancelAll()
            
            guard let credentials else { throw WitlyProvisioningError.timedOut }
            return credentials
        }
    }
    
    // MARK: - Indicators
    
    private static let holdingIndicatorID = "WitlyOnboardingHolding"
    
    private func startHoldingIndicator() {
        parameters.userIndicatorController.submitIndicator(UserIndicator(id: Self.holdingIndicatorID,
                                                                         type: .modal,
                                                                         title: "Setting up your inbox…",
                                                                         persistent: true))
    }
    
    private func stopHoldingIndicator() {
        parameters.userIndicatorController.retractIndicatorWithId(Self.holdingIndicatorID)
    }
    
    private func showFailureIndicator() {
        parameters.userIndicatorController.submitIndicator(UserIndicator(title: "Something went wrong. Please try again.",
                                                                         icon: \.close))
    }
}
