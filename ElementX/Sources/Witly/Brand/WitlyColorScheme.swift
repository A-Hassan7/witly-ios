//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI

/// A swappable brand palette. Values are the exact hex colours used by the Witly web client
/// (`client/witly-web/apps/web/src/witly/brand/witly-tokens.pcss`), ported here 1:1.
///
/// Kept as a plain value type (not baked into `WitlyCompoundHook`) so introducing an alternate
/// palette later is a new `WitlyColorScheme` value, not a code change to the hook.
struct WitlyColorScheme: Sendable {
    let accent: Color
    let accentPressed: Color
    let onAccent: Color
    /// 4-stop approximation of the brand's 2-stop 135° gradient (accent → lighter accent).
    let gradientStops: [Color]
}

extension WitlyColorScheme {
    /// The shipping default. Matches web light-mode `--witly-accent` / `--witly-accent-pressed` /
    /// `--witly-accent-gradient`.
    static let violet = WitlyColorScheme(accent: Color(red: 0x7A / 255, green: 0x5A / 255, blue: 0xF8 / 255),
                                         accentPressed: Color(red: 0x5A / 255, green: 0x37 / 255, blue: 0xD8 / 255),
                                         onAccent: .white,
                                         gradientStops: [
                                             Color(red: 0x7A / 255, green: 0x5A / 255, blue: 0xF8 / 255),
                                             Color(red: 0x86 / 255, green: 0x62 / 255, blue: 0xFA / 255),
                                             Color(red: 0x93 / 255, green: 0x69 / 255, blue: 0xFC / 255),
                                             Color(red: 0xA0 / 255, green: 0x6B / 255, blue: 0xFF / 255)
                                         ])
}

enum WitlyBrand {
    /// The active brand palette. Swap this one line to ship an alternate scheme.
    static let colorScheme: WitlyColorScheme = .violet
}
