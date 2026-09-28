//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// The Witly bottom sheet's four tabs (product-spec §7.3). Ask AI and Wits are shells in this pass —
/// see `WitlyPanelPlaceholderView` — while Suggestions and Settings are fully wired.
enum WitlyPanelTab: CaseIterable, Identifiable {
    case suggestions
    case askAI
    case wits
    case settings
    
    var id: Self {
        self
    }
    
    var title: String {
        switch self {
        case .suggestions: "Suggestions"
        case .askAI: "Ask AI"
        case .wits: "Wits"
        case .settings: "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .suggestions: "sparkles"
        case .askAI: "bubble.left.and.bubble.right"
        case .wits: "person.2"
        case .settings: "slider.horizontal.3"
        }
    }
}
