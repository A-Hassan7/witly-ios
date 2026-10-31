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
    
    /// Exact bridge-bot localparts (`appservice.bot.username` in each bridge's config.yaml — a
    /// single fixed account per bridge, unlike the per-contact ghost prefixes above).
    private static let botLocalparts = ["whatsappbot"]
    
    /// True if `userID` (a full `@localpart:server` Matrix ID) is a recognised bridge ghost.
    static func isBridgeGhost(userID: String) -> Bool {
        guard let localpart = localpart(of: userID) else { return false }
        return ghostLocalpartPrefixes.contains { localpart.hasPrefix($0) }
    }
    
    /// True if `userID` is a recognised bridge bot account (e.g. `@whatsappbot:<server>`), which —
    /// like ghosts — actually owns the megolm session for every message the bridge relays, including
    /// the double-puppeted messages it sends on behalf of the logged-in Witly user.
    static func isBridgeBot(userID: String) -> Bool {
        guard let localpart = localpart(of: userID) else { return false }
        return botLocalparts.contains { $0 == localpart }
    }
    
    /// True if `userID` is any recognised bridge-owned identity (ghost or bot).
    static func isBridgeIdentity(userID: String) -> Bool {
        isBridgeGhost(userID: userID) || isBridgeBot(userID: userID)
    }
    
    /// True if any of `memberIDs` (a room's member list) is a recognised bridge identity — i.e.
    /// this room is managed by a mautrix bridge. Intended to be computed once per room (e.g. from
    /// the room's member list) rather than re-derived per timeline item.
    static func isBridgedRoom(memberIDs: some Sequence<String>) -> Bool {
        memberIDs.contains { isBridgeIdentity(userID: $0) }
    }
    
    private static func localpart(of userID: String) -> Substring? {
        guard userID.hasPrefix("@"), let colonIndex = userID.firstIndex(of: ":") else {
            return nil
        }
        return userID[userID.index(after: userID.startIndex)..<colonIndex]
    }
}
