//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// A simple indeterminate loading bar (a highlight sliding back and forth along a track), used for
/// Witly's "we're setting things up" waiting screens where a determinate percentage would be
/// misleading.
///
/// Driven by `TimelineView` (a pure function of wall-clock time) rather than a toggled `@State` +
/// `withAnimation(...).repeatForever()`, since the latter gets silently cut short whenever anything
/// else in the view hierarchy re-renders (e.g. a sibling's rotating text) — a well-known SwiftUI
/// gotcha where an unrelated state change can interrupt an in-flight `repeatForever` animation.
struct WitlyIndeterminateBar: View {
    private static let period: TimeInterval = 1.1
    
    var body: some View {
        // Disambiguated from Element's own `TimelineView` (the chat timeline), which shares this name.
        SwiftUI.TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.compound.bgSubtleSecondaryLevel0)
                    Capsule()
                        .fill(Color.compound.iconAccentTertiary)
                        .frame(width: geometry.size.width * 0.35)
                        .offset(x: Self.phase(at: timeline.date) * geometry.size.width * 0.65)
                }
            }
        }
        .frame(height: 6)
    }
    
    /// A 0...1 "ease-in-out" triangle wave, one full back-and-forth cycle every `2 * period`.
    private static func phase(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period * 2)
        let linear = t <= period ? t / period : 2 - t / period
        return linear * linear * (3 - 2 * linear) // smoothstep
    }
}
