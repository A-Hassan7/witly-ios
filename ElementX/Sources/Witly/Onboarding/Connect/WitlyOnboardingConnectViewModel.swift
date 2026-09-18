//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

typealias WitlyOnboardingConnectViewModelType = StateStoreViewModelV2<WitlyOnboardingConnectViewState, WitlyOnboardingConnectViewAction>

private let whatsAppFlowID = "phone"

/// Drives the WhatsApp connect step: deploy/register the bridge, phone-number login, pairing-code
/// long-poll, then completion — mirroring the web fork's `ConnectDialog` state machine against the
/// same `/bridges/whatsapp/...` provisioning endpoints.
final class WitlyOnboardingConnectViewModel: WitlyOnboardingConnectViewModelType, WitlyOnboardingConnectViewModelProtocol {
    private let api: AGChatAPIClient
    private let connectController: WitlyBridgeConnectController
    
    private var loginId: String?
    private var currentStep: LoginStep?
    
    private let actionsSubject: PassthroughSubject<WitlyOnboardingConnectViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WitlyOnboardingConnectViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(witlySession: WitlySession) {
        api = AGChatAPIClient(session: witlySession)
        connectController = WitlyBridgeConnectController(api: api)
        super.init(initialViewState: .init(bindings: .init()))
    }
    
    override func process(viewAction: WitlyOnboardingConnectViewAction) {
        switch viewAction {
        case .connectWhatsApp, .retryPrepare:
            prepare()
        case .submitPhone:
            Task { await startLogin() }
        case .startOver:
            loginId = nil
            currentStep = nil
            state.errorMessage = nil
            state.pairingCode = nil
            state.phase = .phone
        case .skip:
            actionsSubject.send(.finished)
        case .finish:
            actionsSubject.send(.finished)
        }
    }
    
    // MARK: - Private
    
    private func prepare() {
        state.phase = .preparing
        state.errorMessage = nil
        state.prepareDetail = "Hang tight — magic in progress"
        
        Task {
            do {
                _ = try await connectController.ensureBridgeReady(service: .whatsapp)
                state.phase = .phone
            } catch {
                WitlyLog.error("Failed preparing WhatsApp bridge: \(error)")
                state.errorMessage = "That didn't work. Please try again."
            }
        }
    }
    
    private func startLogin() async {
        let phone = state.bindings.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phone.count > 4 else {
            state.errorMessage = "Enter a valid phone number."
            return
        }
        
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }
        
        do {
            var step = try await api.startBridgeLogin(service: .whatsapp, flowId: whatsAppFlowID)
            loginId = step.loginId
            
            if step.type == "user_input", let id = loginId {
                step = try await api.submitBridgeLoginStep(service: .whatsapp, loginId: id, stepId: step.stepId,
                                                           stepType: step.type, data: ["phone_number": phone])
                loginId = step.loginId ?? loginId
            }
            
            apply(step)
        } catch {
            WitlyLog.error("Failed starting WhatsApp login: \(error)")
            state.errorMessage = "Couldn't start the connection. Please try again."
        }
    }
    
    /// Long-polls a `display_and_wait` step until the bridge reports `complete`.
    private func waitForPairing() async {
        guard let loginId, let stepId = currentStep?.stepId, state.phase == .pairing else { return }
        
        do {
            let step = try await api.submitBridgeLoginStep(service: .whatsapp, loginId: loginId,
                                                           stepId: stepId, stepType: "display_and_wait", data: [:])
            apply(step)
            if state.phase == .pairing {
                await waitForPairing()
            }
        } catch {
            WitlyLog.error("Lost the WhatsApp pairing long-poll: \(error)")
            state.errorMessage = "We didn't hear back from WhatsApp in time. Please try again."
        }
    }
    
    private func apply(_ step: LoginStep) {
        currentStep = step
        switch step.type {
        case "display_and_wait":
            state.pairingCode = step.displayAndWait?.data
            state.phase = .pairing
            Task { await waitForPairing() }
        case "complete":
            state.phase = .connected
        default:
            break
        }
    }
}
