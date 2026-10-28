//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import Foundation
import Observation
import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted whenever the active theme changes, for UIKit consumers that can't rely on the
    /// Observation framework (e.g. `TimelineTableViewController`'s background view). SwiftUI code
    /// should read `WitlyBrand.colorScheme` (or `WitlyThemeStore.shared.current`) directly instead —
    /// that already updates reactively via `@Observable`.
    static let witlyThemeDidChange = Notification.Name("uk.agchat.witly.themeDidChange")
}

/// Owns the active `WitlyColorScheme` and persists the user's choice across launches.
///
/// `select(_:)` is the single entry point for changing the theme — it persists the choice, re-colors
/// Compound's tokens via `WitlyCompoundHook`, and notifies UIKit observers, so callers never need to
/// touch more than one of those three concerns by hand.
@MainActor
@Observable
final class WitlyThemeStore {
    static let shared = WitlyThemeStore()
    
    private(set) var current: WitlyColorScheme
    
    private static let storageKey = "witly.theme.id"
    
    private init() {
        let savedID = UserDefaults.standard.string(forKey: Self.storageKey)
        let initial = WitlyColorScheme.all.first { $0.id == savedID } ?? .violet
        current = initial
        WitlyCompoundHook.apply(initial, colors: Color.compound, uiColors: UIColor.compound)
    }
    
    /// Switches the active theme, persists the choice, and immediately re-colors the running UI.
    func select(_ scheme: WitlyColorScheme) {
        current = scheme
        UserDefaults.standard.set(scheme.id, forKey: Self.storageKey)
        WitlyCompoundHook.apply(scheme, colors: Color.compound, uiColors: UIColor.compound)
        NotificationCenter.default.post(name: .witlyThemeDidChange, object: scheme)
    }
}
