//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI
import UIKit

/// Recolors Compound's action/accent tokens with the Witly brand, via the app's own
/// `CompoundHookProtocol` extension point — no core edit required. Registered by
/// `WitlyAppHooks.install(into:)`.
struct WitlyCompoundHook: CompoundHookProtocol {
    @MainActor
    func override(colors: CompoundColors, uiColors: CompoundUIColors) {
        Self.apply(WitlyBrand.colorScheme, colors: colors, uiColors: uiColors)
    }
    
    /// Applies a specific scheme directly rather than reading `WitlyBrand.colorScheme` (which reads
    /// `WitlyThemeStore.shared`) — used by `WitlyThemeStore` itself during its own initialization and
    /// on every theme switch, where going through `.shared` would reenter the store it's inside of.
    @MainActor
    static func apply(_ scheme: WitlyColorScheme, colors: CompoundColors, uiColors: CompoundUIColors) {
        colors.override(\.bgActionPrimaryRest, with: scheme.accent)
        colors.override(\.bgActionPrimaryPressed, with: scheme.accentPressed)
        colors.override(\.bgAccentRest, with: scheme.accent)
        colors.override(\.textActionPrimary, with: scheme.accent)
        colors.override(\.iconAccentPrimary, with: scheme.accent)
        colors.override(\.iconAccentTertiary, with: scheme.accent)
        colors.override(\.gradientActionStop1, with: scheme.gradientStops[0])
        colors.override(\.gradientActionStop2, with: scheme.gradientStops[1])
        colors.override(\.gradientActionStop3, with: scheme.gradientStops[2])
        colors.override(\.gradientActionStop4, with: scheme.gradientStops[3])
        
        // Placeholder tokens (seam: compound-ios/Sources/Compound/Colors/CompoundColors.swift) — not
        // part of the keyPath-based override dictionary above, so set directly.
        colors._bgBubbleIncoming = scheme.bubbleIncoming
        colors._bgBubbleOutgoing = scheme.bubbleOutgoing
        
        let uiAccent = UIColor(scheme.accent)
        uiColors.override(\.bgActionPrimaryRest, with: uiAccent)
        uiColors.override(\.bgActionPrimaryPressed, with: UIColor(scheme.accentPressed))
        uiColors.override(\.bgAccentRest, with: uiAccent)
        uiColors.override(\.textActionPrimary, with: uiAccent)
        uiColors.override(\.iconAccentPrimary, with: uiAccent)
        uiColors.override(\.iconAccentTertiary, with: uiAccent)
    }
}
