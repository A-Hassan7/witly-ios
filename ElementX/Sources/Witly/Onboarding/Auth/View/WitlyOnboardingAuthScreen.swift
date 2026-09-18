//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// The auth step of Witly onboarding: Google, email or phone sign-in against Supabase.
struct WitlyOnboardingAuthScreen: View {
    @Bindable var context: WitlyOnboardingAuthViewModel.Context
    
    var body: some View {
        FullscreenDialog {
            header
        } bottomContent: {
            VStack(spacing: 16) {
                if let errorMessage = context.viewState.errorMessage {
                    Text(errorMessage)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textCriticalPrimary)
                        .multilineTextAlignment(.center)
                }
                
                content
            }
        }
        .background()
        .backgroundStyle(.compound.bgCanvasDefault)
        .disabled(context.viewState.isLoading)
        .interactiveDismissDisabled()
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            BigIcon(icon: \.userProfileSolid)
                .padding(.bottom, 8)
            Text("Sign in to Witly")
                .font(.compound.headingMDBold)
                .foregroundColor(.compound.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Your account keeps your chats and settings in sync.")
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var content: some View {
        switch context.viewState.mode {
        case .chooser:
            chooserContent
        case .emailCode(let email):
            codeContent(destination: email, sendAction: .sendEmailCode, verifyAction: .verifyEmailCode)
        case .phoneCode(let phone):
            codeContent(destination: phone, sendAction: .sendPhoneCode, verifyAction: .verifyPhoneCode)
        }
    }
    
    private var chooserContent: some View {
        VStack(spacing: 16) {
            Button {
                context.send(viewAction: .continueWithGoogle)
            } label: {
                Text("Continue with Google")
            }
            .buttonStyle(.compound(.primary))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.compound.bodySMSemibold)
                    .foregroundColor(.compound.textPrimary)
                TextField("you@example.com", text: $context.emailAddress)
                    .textFieldStyle(.compound(labelText: nil, footerText: nil, state: .default, accessibilityIdentifier: "witlyEmailField"))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Button(L10n.actionContinue) {
                context.send(viewAction: .sendEmailCode)
            }
            .buttonStyle(.compound(.secondary))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone")
                    .font(.compound.bodySMSemibold)
                    .foregroundColor(.compound.textPrimary)
                TextField("+1 555 555 5555", text: $context.phoneNumber)
                    .textFieldStyle(.compound(labelText: nil, footerText: nil, state: .default, accessibilityIdentifier: "witlyPhoneField"))
                    .keyboardType(.phonePad)
            }
            
            Button(L10n.actionContinue) {
                context.send(viewAction: .sendPhoneCode)
            }
            .buttonStyle(.compound(.secondary))
            
            if context.viewState.isLoading {
                ProgressView()
            }
        }
    }
    
    private func codeContent(destination: String, sendAction: WitlyOnboardingAuthViewAction, verifyAction: WitlyOnboardingAuthViewAction) -> some View {
        VStack(spacing: 16) {
            Text("We sent a code to \(destination)")
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
                .multilineTextAlignment(.center)
            
            TextField("Enter code", text: $context.code)
                .textFieldStyle(.compound(labelText: nil, footerText: nil, state: .default, accessibilityIdentifier: "witlyCodeField"))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
            
            Button(L10n.actionContinue) {
                context.send(viewAction: verifyAction)
            }
            .buttonStyle(.compound(.primary))
            
            if context.viewState.isLoading {
                ProgressView()
            }
            
            Button("Resend code") {
                context.send(viewAction: sendAction)
            }
            .buttonStyle(.compound(.tertiary, size: .small))
            
            Button(L10n.actionBack) {
                context.send(viewAction: .goBack)
            }
            .buttonStyle(.compound(.tertiary, size: .small))
        }
    }
}

struct WitlyOnboardingAuthScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = WitlyOnboardingAuthViewModel(witlySession: WitlySession(),
                                                        presentationAnchor: UIWindow())
    
    static var previews: some View {
        WitlyOnboardingAuthScreen(context: viewModel.context)
    }
}
