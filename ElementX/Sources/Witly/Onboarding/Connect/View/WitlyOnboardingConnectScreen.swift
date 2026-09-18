//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// The connect step of onboarding: picker (WhatsApp today, others "coming soon") → preparing →
/// phone entry → pairing code → connected. Mirrors the web fork's `ConnectDialog`.
struct WitlyOnboardingConnectScreen: View {
    @Bindable var context: WitlyOnboardingConnectViewModel.Context
    
    var body: some View {
        Group {
            switch context.viewState.phase {
            case .picker:
                picker
            case .preparing:
                preparing
            case .phone:
                phoneEntry
            case .pairing:
                pairing
            case .connected:
                connected
            }
        }
        .background()
        .backgroundStyle(.compound.bgCanvasDefault)
        .interactiveDismissDisabled()
    }
    
    // MARK: - Picker
    
    private var picker: some View {
        FullscreenDialog {
            VStack(spacing: 16) {
                BigIcon(icon: \.chatSolid)
                Text("Connect your chats")
                    .font(.compound.headingMDBold)
                    .foregroundColor(.compound.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Bring your conversations into Witly. Pick where you chat and we'll link it up.")
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 10) {
                    platformRow(emoji: "🟢", name: "WhatsApp", subtitle: "Link with your phone number", enabled: true) {
                        context.send(viewAction: .connectWhatsApp)
                    }
                    platformRow(emoji: "📸", name: "Instagram", subtitle: "Coming soon", enabled: false, action: nil)
                    platformRow(emoji: "💬", name: "Messenger", subtitle: "Coming soon", enabled: false, action: nil)
                    platformRow(emoji: "🎮", name: "Discord", subtitle: "Coming soon", enabled: false, action: nil)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
        } bottomContent: {
            Button("Skip for now") {
                context.send(viewAction: .skip)
            }
            .buttonStyle(.compound(.tertiary))
        }
    }
    
    private func platformRow(emoji: String, name: String, subtitle: String, enabled: Bool, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 14) {
                Text(emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.compound.bodyLGSemibold)
                        .foregroundColor(.compound.textPrimary)
                    Text(subtitle)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textSecondary)
                }
                Spacer()
                if enabled {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.compound.iconAccentTertiary)
                } else {
                    Text("Soon")
                        .font(.compound.bodyXSSemibold)
                        .foregroundColor(.compound.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.compound.bgSubtleSecondaryLevel0)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(Color.compound.bgCanvasDefault)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.compound.borderInteractiveSecondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(enabled ? 1 : 0.6)
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
    
    // MARK: - Preparing
    
    private var preparing: some View {
        FullscreenDialog {
            VStack(spacing: 16) {
                BigIcon(icon: \.chatSolid)
                if let errorMessage = context.viewState.errorMessage {
                    Text("That didn't work")
                        .font(.compound.headingMDBold)
                        .foregroundColor(.compound.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(errorMessage)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textCriticalPrimary)
                        .multilineTextAlignment(.center)
                    Button(L10n.actionRetry) {
                        context.send(viewAction: .retryPrepare)
                    }
                    .buttonStyle(.compound(.primary))
                } else {
                    Text(context.viewState.prepareDetail)
                        .font(.compound.headingMDBold)
                        .foregroundColor(.compound.textPrimary)
                        .multilineTextAlignment(.center)
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
        } bottomContent: { EmptyView() }
    }
    
    // MARK: - Phone entry
    
    private var phoneEntry: some View {
        FullscreenDialog {
            VStack(spacing: 16) {
                BigIcon(icon: \.chatSolid)
                Text("What's your WhatsApp number?")
                    .font(.compound.headingMDBold)
                    .foregroundColor(.compound.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Enter the number linked to your WhatsApp account. You'll get a code to confirm it's you.")
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .multilineTextAlignment(.center)
                
                WitlyPhoneNumberField(value: $context.phoneNumber)
            }
            .padding(.horizontal, 16)
        } bottomContent: {
            VStack(spacing: 12) {
                if let errorMessage = context.viewState.errorMessage {
                    Text(errorMessage)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textCriticalPrimary)
                        .multilineTextAlignment(.center)
                }
                Button(context.viewState.isLoading ? "Just a sec…" : "Send me a code") {
                    context.send(viewAction: .submitPhone)
                }
                .buttonStyle(.compound(.primary))
                .disabled(context.viewState.isLoading)
            }
        }
    }
    
    // MARK: - Pairing
    
    private var pairing: some View {
        FullscreenDialog {
            VStack(spacing: 16) {
                BigIcon(icon: \.chatSolid)
                Text("Check your phone for a WhatsApp alert")
                    .font(.compound.headingMDBold)
                    .foregroundColor(.compound.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Open WhatsApp → Linked devices → Link a device, then enter this code.")
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .multilineTextAlignment(.center)
                
                if let errorMessage = context.viewState.errorMessage {
                    Text(errorMessage)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textCriticalPrimary)
                        .multilineTextAlignment(.center)
                } else if let code = context.viewState.pairingCode {
                    Text(code)
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundColor(.compound.textActionAccent)
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for your phone…")
                            .font(.compound.bodySM)
                            .foregroundColor(.compound.textSecondary)
                    }
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
        } bottomContent: {
            Button(L10n.actionStartOver) {
                context.send(viewAction: .startOver)
            }
            .buttonStyle(.compound(.tertiary))
        }
    }
    
    // MARK: - Connected
    
    private var connected: some View {
        FullscreenDialog {
            VStack(spacing: 16) {
                BigIcon(icon: \.checkCircleSolid, style: .successSolid)
                Text("WhatsApp is connected!")
                    .font(.compound.headingMDBold)
                    .foregroundColor(.compound.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Your chats are on their way in. It can take a moment for everything to show up.")
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
        } bottomContent: {
            Button("Take me to my chats") {
                context.send(viewAction: .finish)
            }
            .buttonStyle(.compound(.primary))
        }
    }
}

struct WitlyOnboardingConnectScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = WitlyOnboardingConnectViewModel(witlySession: WitlySession())
    
    static var previews: some View {
        WitlyOnboardingConnectScreen(context: viewModel.context)
    }
}
