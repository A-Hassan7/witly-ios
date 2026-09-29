//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

extension View {
    /// The shared suggestion-card surface used by both the compact carousel (`WitlySuggestionsBarView`)
    /// and the panel's Suggestions tab (`WitlyPanelSuggestionsView`): a base fill with a subtle Witly
    /// brand-gradient tint and a hairline border, so cards read as distinctly "Witly" rather than a
    /// plain grey card.
    ///
    /// Uses `bgSubtlePrimary`, not `bgSubtleSecondaryLevel0` — the latter is identical to
    /// `bgCanvasDefault` in dark mode (`#101317` == `#101317`), which made cards invisible against
    /// their own container and indistinguishable from each other.
    func witlySuggestionCardBackground(cornerRadius: CGFloat = 14) -> some View {
        background(RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.compound.bgSubtlePrimary)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(colors: WitlyBrand.colorScheme.gradientStops,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.compound.borderInteractiveSecondary, lineWidth: 0.5))
    }
}
