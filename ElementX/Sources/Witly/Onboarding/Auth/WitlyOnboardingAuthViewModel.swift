//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

typealias WitlyOnboardingAuthViewModelType = StateStoreViewModelV2<WitlyOnboardingAuthViewState, WitlyOnboardingAuthViewAction>

/// Drives the auth step of Witly onboarding: Google OAuth, or email/phone OTP against Supabase.
/// On success it establishes the `WitlySession` (persisted independently of Element's Matrix
/// keychain — see `WitlySession`) and notifies the flow coordinator via `.authenticated`.
final class WitlyOnboardingAuthViewModel: WitlyOnboardingAuthViewModelType, WitlyOnboardingAuthViewModelProtocol {
    private let witlySession: WitlySession
    private let authService: SupabaseAuthService
    private let oauthPresenter: SupabaseOAuthPresenter
    
    private let actionsSubject: PassthroughSubject<WitlyOnboardingAuthViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WitlyOnboardingAuthViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(witlySession: WitlySession, presentationAnchor: UIWindow) {
        self.witlySession = witlySession
        authService = SupabaseAuthService()
        oauthPresenter = SupabaseOAuthPresenter(presentationAnchor: presentationAnchor)
        super.init(initialViewState: .init(bindings: .init()))
    }
    
    override func process(viewAction: WitlyOnboardingAuthViewAction) {
        state.errorMessage = nil
        
        switch viewAction {
        case .continueWithGoogle:
            Task { await signInWithGoogle() }
        case .sendEmailCode:
            Task { await sendEmailCode() }
        case .verifyEmailCode:
            Task { await verifyEmailCode() }
        case .sendPhoneCode:
            Task { await sendPhoneCode() }
        case .verifyPhoneCode:
            Task { await verifyPhoneCode() }
        case .goBack:
            state.mode = .chooser
            state.bindings.code = ""
        }
    }
    
    // MARK: - Private
    
    private func signInWithGoogle() async {
        state.isLoading = true
        defer { state.isLoading = false }
        
        switch await oauthPresenter.signInWithGoogle() {
        case .success(let session):
            await witlySession.establish(from: session)
            actionsSubject.send(.authenticated)
        case .failure(let error):
            // A user-initiated cancellation shouldn't surface as an error.
            guard error.message != "cancelled" else { return }
            WitlyLog.error("Google sign-in failed: \(error)")
            state.errorMessage = "Google sign-in failed. Please try again."
        }
    }
    
    private func sendEmailCode() async {
        let email = state.bindings.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@") else {
            state.errorMessage = "Enter a valid email address."
            return
        }
        
        state.isLoading = true
        defer { state.isLoading = false }
        
        do {
            try await authService.sendEmailOTP(email: email, redirectTo: nil)
            state.mode = .emailCode(email: email)
        } catch {
            WitlyLog.error("Failed sending email OTP: \(error)")
            state.errorMessage = "Couldn't send the code. Please try again."
        }
    }
    
    private func verifyEmailCode() async {
        guard case .emailCode(let email) = state.mode else { return }
        
        state.isLoading = true
        defer { state.isLoading = false }
        
        do {
            let session = try await authService.verifyEmailOTP(email: email, token: state.bindings.code)
            await witlySession.establish(from: session)
            actionsSubject.send(.authenticated)
        } catch {
            WitlyLog.error("Failed verifying email OTP: \(error)")
            state.errorMessage = "That code didn't work. Please try again."
        }
    }
    
    private func sendPhoneCode() async {
        let phone = state.bindings.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phone.isEmpty else {
            state.errorMessage = "Enter a valid phone number."
            return
        }
        
        state.isLoading = true
        defer { state.isLoading = false }
        
        do {
            try await authService.sendPhoneOTP(phone: phone)
            state.mode = .phoneCode(phone: phone)
        } catch {
            WitlyLog.error("Failed sending phone OTP: \(error)")
            state.errorMessage = "Couldn't send the code. Please try again."
        }
    }
    
    private func verifyPhoneCode() async {
        guard case .phoneCode(let phone) = state.mode else { return }
        
        state.isLoading = true
        defer { state.isLoading = false }
        
        do {
            let session = try await authService.verifyPhoneOTP(phone: phone, token: state.bindings.code)
            await witlySession.establish(from: session)
            actionsSubject.send(.authenticated)
        } catch {
            WitlyLog.error("Failed verifying phone OTP: \(error)")
            state.errorMessage = "That code didn't work. Please try again."
        }
    }
}
