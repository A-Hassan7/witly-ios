//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Recognises Matrix user IDs belonging to mautrix bridge ghosts (remote-contact puppets), so
/// bridge-specific crypto/verification quirks can be told apart from genuine Matrix-native issues.
/// Centralised here rather than scattered `hasPrefix("@whatsapp_")` checks, so adding Meta/Instagram/
/// Telegram support later is a one-line addition to `ghostLocalpartPrefixes`.
nonisolated enum WitlyBridgeIdentity {
    /// Localpart prefixes mautrix bridges assign to their ghost users, taken from each bridge's
    /// `appservice.username_template` config (e.g. `infrastructure/bridges/whatsapp/config.yaml`'s
    /// `username_template: whatsapp_{{.}}`). Mirrors the equivalent classifier on web
    /// (`client/witly-web/apps/web/src/matrix/platformDetection.ts`'s `GHOST_PREFIXES`).
    private static let ghostLocalpartPrefixes = ["whatsapp_"]
    
    /// True if `userID` (a full `@localpart:server` Matrix ID) is a recognised bridge ghost.
    static func isBridgeGhost(userID: String) -> Bool {
        guard userID.hasPrefix("@"), let colonIndex = userID.firstIndex(of: ":") else {
            return false
        }
        let localpart = userID[userID.index(after: userID.startIndex)..<colonIndex]
        return ghostLocalpartPrefixes.contains { localpart.hasPrefix($0) }
    }
}
