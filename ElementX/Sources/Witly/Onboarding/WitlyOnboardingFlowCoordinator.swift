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

/// Drives Witly's onboarding — intro → auth → connect — replacing Element's own
/// `AuthenticationFlowCoordinator` at the seam in `AppCoordinator.startAuthentication()`.
///
/// Per product decision there's no Wit-selection step and no unconditional "loading" screen:
/// provisioning is kicked off in the background as soon as auth succeeds, and the I2-2 account-setup
/// screen is only shown (right before "Connect your chats") if it hasn't finished yet.
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
    /// Set (success or failure) when `provisioningTask` finishes; checked synchronously by
    /// `isProvisioningLikelyReady()` after its grace period, since a `Task` exposes no such flag.
    private var isProvisioningComplete = false
    
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
                self?.handleAuthenticated()
            }
        }
        .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    /// I2-2: gate on account readiness right here, before "Connect your chats" — not with an
    /// unconditional loading screen, only if provisioning genuinely isn't ready yet.
    private func handleAuthenticated() {
        beginProvisioning()
        
        Task {
            if await isProvisioningLikelyReady() {
                presentConnect()
            } else {
                presentAccountSetup()
            }
        }
    }
    
    private func presentAccountSetup() {
        let coordinator = WitlyOnboardingAccountSetupCoordinator()
        navigationStackCoordinator.push(coordinator)
        
        Task {
            // Errors surface later at the actual restore step; this screen has no error UI (I2-2).
            _ = try? await provisioningTask?.value
            navigationStackCoordinator.pop()
            presentConnect()
        }
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
        isProvisioningComplete = false
        provisioningTask = Task {
            defer { isProvisioningComplete = true }
            return try await provisioning.provision()
        }
    }
    
    /// Waits out a short grace period so a fast provision never flashes the account-setup screen
    /// at all. Deliberately doesn't race against `provisioningTask` directly in a `TaskGroup`: an
    /// unbounded `await task.value` inside a task-group child doesn't respect `cancelAll()` (it
    /// only stops checking for cancellation at its own suspension points, of which there are none
    /// here), so `withTaskGroup` wouldn't actually return until the real (potentially 30-60s)
    /// provisioning finished — silently defeating the whole point of the race.
    private func isProvisioningLikelyReady() async -> Bool {
        try? await Task.sleep(for: .milliseconds(300))
        return isProvisioningComplete
    }
    
    private func finishOnboarding() {
        Task {
            do {
                guard let credentials = try await provisioningTask?.value else {
                    throw WitlyProvisioningError.missingCredentials
                }
                
                switch await sessionRestorer.restore(credentials: credentials) {
                case .success(let userSession):
                    delegate?.witlyOnboardingFlowCoordinator(didLoginWithSession: userSession)
                case .failure(let error):
                    WitlyLog.error("Failed restoring provisioned session: \(error)")
                    showFailureIndicator()
                }
            } catch {
                WitlyLog.error("Provisioning failed: \(error)")
                showFailureIndicator()
            }
        }
    }
    
    // MARK: - Indicators
    
    private func showFailureIndicator() {
        parameters.userIndicatorController.submitIndicator(UserIndicator(title: "Something went wrong. Please try again.",
                                                                         icon: \.close))
    }
}
