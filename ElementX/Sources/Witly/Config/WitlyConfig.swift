//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Backend + Supabase configuration for the Witly layer, mirroring the web fork's `config.json`.
///
/// Values are read from `Info.plist` (`WitlyAPIBase`, `WitlySupabaseURL`, `WitlySupabaseKey`),
/// which xcodegen populates from a `Witly.xcconfig` so dev/prod can differ without code changes.
/// The Supabase URL + publishable key are intentionally public (Row Level Security controls access,
/// exactly as the web fork ships them), so the dev fallbacks below are safe defaults for Simulator
/// builds where the plist keys aren't set yet.
nonisolated enum WitlyConfig {
    /// AGChat control-plane base URL (no trailing slash).
    static var apiBase: String {
        plistString("WitlyAPIBase") ?? devAPIBase
    }
    
    /// Supabase project URL (no trailing slash).
    static var supabaseURL: String {
        (plistString("WitlySupabaseURL") ?? devSupabaseURL).trimmingTrailingSlash
    }
    
    /// Supabase publishable/anon key. Public by design.
    static var supabaseKey: String {
        plistString("WitlySupabaseKey") ?? devSupabaseKey
    }
    
    // MARK: - Dev fallbacks (Simulator-first; overridden by Info.plist in prod)
    
    // The backend API base for local dev. Points at the deployed control plane; override via
    // `WitlyAPIBase` in Info.plist / Witly.xcconfig for other environments.
    private static let devAPIBase = "https://api.agchat.uk"
    private static let devSupabaseURL = "https://ulznjrbhhnkqyajsarxx.supabase.co"
    private static let devSupabaseKey = "sb_publishable_5q4-qUsxEe6M1289ZkkBsQ_shfB4uEv"
    
    private static func plistString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}

private extension String {
    nonisolated var trimmingTrailingSlash: String {
        hasSuffix("/") ? String(dropLast()) : self
    }
}
