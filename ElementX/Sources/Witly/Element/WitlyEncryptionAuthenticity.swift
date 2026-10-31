//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension EncryptionAuthenticity {
    /// Hides the `.mismatchedSender` shield for recognised bridge ghosts — an expected artifact of
    /// mautrix's bridge encryption topology (the event's sender is the remote-contact ghost, but the
    /// megolm session belongs to the bridge bot's own device/identity), not a real security concern.
    /// Every other authenticity state — including genuine undecryptable or verification-violation
    /// cases — is returned unchanged, even for bridge ghosts, so real crypto failures are never hidden.
    nonisolated func witlyFiltered(senderID: String) -> EncryptionAuthenticity? {
        if case .mismatchedSender = self, WitlyBridgeIdentity.isBridgeGhost(userID: senderID) {
            return nil
        }
        return self
    }
    
    /// As `witlyFiltered(senderID:)`, but additionally hides `.mismatchedSender` for the *own*
    /// double-puppeted messages inside a bridged room: every outgoing `sender: @user:...` event the
    /// bridge relays is actually encrypted by the bridge bot's own device, not the real Element X
    /// session's device — expected mautrix behaviour (see
    /// docs.mau.fi/bridges/general/troubleshooting.html#why-are-messages-showing-up-as-encrypted-by-a-deleted-session),
    /// not a genuine impersonation signal. Deliberately scoped to `isBridgedRoom`: a real second
    /// device of the same account can never trigger `mismatchedSender`, so suppressing it for "sender
    /// is self" outside a bridge-managed room would risk hiding a genuine spoofing attempt.
    nonisolated func witlyFiltered(senderID: String, ownUserID: String, isBridgedRoom: Bool)
        -> EncryptionAuthenticity? {
        guard case .mismatchedSender = self else { return self }
        if WitlyBridgeIdentity.isBridgeGhost(userID: senderID) {
            return nil
        }
        if isBridgedRoom, senderID == ownUserID {
            return nil
        }
        return self
    }
}

extension EventBasedTimelineItemProtocol {
    /// `properties.encryptionAuthenticity` with expected bridge-ghost noise suppressed (see
    /// `EncryptionAuthenticity.witlyFiltered(senderID:)`). Used only where room-level context (own
    /// user ID / bridged-room status) isn't cheaply available, e.g. pure layout-measurement code —
    /// prefer `witlyVisibleEncryptionAuthenticity(ownUserID:isBridgedRoom:)` wherever it's accessible,
    /// since it additionally covers double-puppeted self-sent messages in bridged rooms.
    nonisolated var witlyVisibleEncryptionAuthenticity: EncryptionAuthenticity? {
        properties.encryptionAuthenticity?.witlyFiltered(senderID: sender.id)
    }
    
    /// `properties.encryptionAuthenticity` with bridge-ghost *and* double-puppeted self-send noise
    /// suppressed (see `EncryptionAuthenticity.witlyFiltered(senderID:ownUserID:isBridgedRoom:)`).
    /// This is the version every interactive user-facing surface (status icon, tap-to-view alert,
    /// context menu) should read, so the raw property stays available unfiltered for anything else.
    nonisolated func witlyVisibleEncryptionAuthenticity(ownUserID: String, isBridgedRoom: Bool)
        -> EncryptionAuthenticity? {
        properties.encryptionAuthenticity?.witlyFiltered(senderID: sender.id, ownUserID: ownUserID, isBridgedRoom: isBridgedRoom)
    }
}
