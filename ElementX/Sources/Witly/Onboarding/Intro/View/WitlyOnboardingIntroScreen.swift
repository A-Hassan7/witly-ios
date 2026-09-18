//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// Value-prop intro screen shown first in onboarding. Mirrors the Figma mobile handover's
/// `OnboardingValueIntro.tsx`: brand mark, headline, a placeholder for the product demo video, and
/// two CTAs ("Get started" for new users, "Sign in" for returning ones — both lead to the same
/// Supabase auth step on iOS).
struct WitlyOnboardingIntroScreen: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.top, 24)
                .padding(.bottom, 20)
            
            headline
                .padding(.bottom, 20)
            
            videoPlaceholder
                .frame(maxHeight: .infinity)
            
            actions
                .padding(.top, 16)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .background()
        .backgroundStyle(.compound.bgCanvasDefault)
    }
    
    private var brand: some View {
        HStack(spacing: 8) {
            Text("✨")
                .font(.title2)
            Text("Witly")
                .font(.compound.headingMDBold)
                .foregroundColor(.compound.textPrimary)
        }
    }
    
    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Be effortlessly witty.")
                .font(.compound.headingLGBold)
                .foregroundColor(.compound.textPrimary)
            Text("Replies like you — just quicker, sharper and funnier.")
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
        }
    }
    
    /// Placeholder for the product demo video (`<video autoPlay muted loop playsInline>` on web).
    private var videoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color.compound.bgSubtleSecondaryLevel0)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.compound.iconAccentTertiary)
                    Text("Product preview")
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textSecondary)
                }
            }
    }
    
    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: onGetStarted) {
                Text("Get started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compound(.primary))
            
            Button(action: onSignIn) {
                Text("Already have an account? Sign in")
            }
            .buttonStyle(.compound(.tertiary, size: .small))
        }
    }
}

struct WitlyOnboardingIntroScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        WitlyOnboardingIntroScreen(onGetStarted: { }, onSignIn: { })
    }
}
