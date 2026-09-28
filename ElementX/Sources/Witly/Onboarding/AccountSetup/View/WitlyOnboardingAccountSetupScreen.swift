//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// I2-2: the account-setup waiting screen. Rotates a playful emoji + witty remark while an
/// indeterminate bar runs underneath a stable "Setting up your Witly…" message. No technical
/// terminology, no percentage/timers, no CTA — this should feel alive, not frozen, for however
/// long the wait takes.
struct WitlyOnboardingAccountSetupScreen: View {
    private static let emojis = ["✨", "⚡", "🪄", "😏", "💬", "🧠"]
    private static let remarks = [
        "Getting your chats a comfy little home…",
        "Warming up the wit…",
        "Making room for the group chat chaos…",
        "Teaching the servers some manners…",
        "Sharpening the comebacks…",
        "Preparing for messages you definitely won't overthink…",
        "Making you look suspiciously quick-witted…",
        "Almost ready for the chaos…"
    ]
    
    @State private var index = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text(Self.emojis[index % Self.emojis.count])
                .font(.system(size: 56))
                .id(index) // re-trigger the transition on every rotation
                .transition(.scale.combined(with: .opacity))
            
            VStack(spacing: 16) {
                WitlyIndeterminateBar()
                    .frame(width: 200)
                
                Text(Self.remarks[index % Self.remarks.count])
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.compound.textPrimary)
                    .multilineTextAlignment(.center)
                    .id(index)
                    .transition(.opacity)
                
                Text("Setting up your Witly…")
                    .font(.compound.bodySM)
                    .foregroundColor(.compound.textSecondary)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Rectangle()
                .fill(RadialGradient(colors: [.compound.bgSubtleSecondaryLevel0, .compound.bgCanvasDefault],
                                     center: .top, startRadius: 0, endRadius: 400))
                .ignoresSafeArea()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.elementDefault) {
                    index += 1
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

struct WitlyOnboardingAccountSetupScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        WitlyOnboardingAccountSetupScreen()
    }
}
