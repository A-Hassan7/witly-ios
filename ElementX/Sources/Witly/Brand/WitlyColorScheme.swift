//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import UIKit

/// A complete, swappable Witly visual theme — brand accent colours, message-bubble colours, and the
/// room background (solid/gradient/pattern, see `WitlyRoomBackground`).
///
/// Kept as a plain value type (not baked into `WitlyCompoundHook`) so introducing a new theme is
/// adding a `static let` to `WitlyColorScheme.all` below — never a code change to the hook, the
/// store, or any consuming view. `WitlyThemeStore` owns which one is active and persists the choice.
struct WitlyColorScheme: Sendable, Identifiable, Equatable {
    /// Stable identifier persisted by `WitlyThemeStore` — never change an existing theme's `id`
    /// once shipped, or a user's saved selection will silently fall back to the default.
    let id: String
    /// Display name for a future theme-picker UI.
    let name: String
    
    let accent: Color
    let accentPressed: Color
    let onAccent: Color
    /// 4-stop approximation of the brand's 2-stop 135° gradient (accent → lighter accent).
    let gradientStops: [Color]
    
    /// Message bubble background colours — replaces Compound's neutral, barely-distinguishable
    /// `_bgBubbleIncoming`/`_bgBubbleOutgoing` placeholder tokens (see `WitlyCompoundHook`).
    let bubbleIncoming: Color
    let bubbleOutgoing: Color
    
    /// The room timeline's background, rendered behind the message bubbles (see
    /// `TimelineTableViewController`).
    let roomBackground: WitlyRoomBackground
}

extension WitlyColorScheme {
    /// The shipping default. Accent/gradient values match web light-mode `--witly-accent` /
    /// `--witly-accent-pressed` / `--witly-accent-gradient`. Bubble colours are a light pastel-violet
    /// tint for outgoing vs. a neutral gray for incoming, dynamic across light/dark mode.
    static let violet = WitlyColorScheme(id: "violet",
                                         name: "Violet",
                                         accent: Color(red: 0x7A / 255, green: 0x5A / 255, blue: 0xF8 / 255),
                                         accentPressed: Color(red: 0x5A / 255, green: 0x37 / 255, blue: 0xD8 / 255),
                                         onAccent: .white,
                                         gradientStops: [
                                             Color(red: 0x7A / 255, green: 0x5A / 255, blue: 0xF8 / 255),
                                             Color(red: 0x86 / 255, green: 0x62 / 255, blue: 0xFA / 255),
                                             Color(red: 0x93 / 255, green: 0x69 / 255, blue: 0xFC / 255),
                                             Color(red: 0xA0 / 255, green: 0x6B / 255, blue: 0xFF / 255)
                                         ],
                                         bubbleIncoming: Color(UIColor {
                                             $0.isWitlyDark
                                                 ? UIColor(white: 0.20, alpha: 1)
                                                 : UIColor(white: 0.90, alpha: 1)
                                         }),
                                         bubbleOutgoing: Color(UIColor {
                                             $0.isWitlyDark
                                                 ? UIColor(red: 0x3A / 255, green: 0x2A / 255, blue: 0x5C / 255, alpha: 1)
                                                 : UIColor(red: 0xE9 / 255, green: 0xE3 / 255, blue: 0xFE / 255, alpha: 1)
                                         }),
                                         roomBackground: .defaultCanvas)
    
    /// A second built-in theme, proving the system end-to-end: a different accent, bubble colours,
    /// and a dotted pattern background rather than a flat colour.
    static let midnight = WitlyColorScheme(id: "midnight",
                                           name: "Midnight",
                                           accent: Color(red: 0x2D / 255, green: 0xD4 / 255, blue: 0xBF / 255),
                                           accentPressed: Color(red: 0x1F / 255, green: 0xA8 / 255, blue: 0x97 / 255),
                                           onAccent: .black,
                                           gradientStops: [
                                               Color(red: 0x2D / 255, green: 0xD4 / 255, blue: 0xBF / 255),
                                               Color(red: 0x3D / 255, green: 0xDE / 255, blue: 0xCB / 255),
                                               Color(red: 0x4D / 255, green: 0xE8 / 255, blue: 0xD7 / 255),
                                               Color(red: 0x5D / 255, green: 0xF2 / 255, blue: 0xE3 / 255)
                                           ],
                                           bubbleIncoming: Color(UIColor {
                                               $0.isWitlyDark
                                                   ? UIColor(white: 0.16, alpha: 1)
                                                   : UIColor(white: 0.88, alpha: 1)
                                           }),
                                           bubbleOutgoing: Color(UIColor {
                                               $0.isWitlyDark
                                                   ? UIColor(red: 0x16 / 255, green: 0x3A / 255, blue: 0x36 / 255, alpha: 1)
                                                   : UIColor(red: 0xDC / 255, green: 0xF5 / 255, blue: 0xF1 / 255, alpha: 1)
                                           }),
                                           roomBackground: .pattern(.dots, tint: Color(red: 0x2D / 255, green: 0xD4 / 255, blue: 0xBF / 255)))
    
    /// All built-in themes, keyed by `id` for `WitlyThemeStore`'s persistence lookup. Add a new theme
    /// by adding a `static let` above and appending it here — nothing else needs to change.
    static let all: [WitlyColorScheme] = [.violet, .midnight]
}

private extension UITraitCollection {
    var isWitlyDark: Bool {
        userInterfaceStyle == .dark
    }
}

enum WitlyBrand {
    /// The active brand palette. Swappable at runtime via `WitlyThemeStore.shared.select(_:)`;
    /// reads live so every call site automatically reflects the current theme.
    static var colorScheme: WitlyColorScheme {
        WitlyThemeStore.shared.current
    }
}
