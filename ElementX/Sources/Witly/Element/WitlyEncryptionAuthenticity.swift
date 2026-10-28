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
}

extension EventBasedTimelineItemProtocol {
    /// `properties.encryptionAuthenticity` with expected bridge-ghost noise suppressed (see
    /// `EncryptionAuthenticity.witlyFiltered(senderID:)`). Every user-facing surface (status icon,
    /// tap-to-view alert, context menu) should read this instead of `properties.encryptionAuthenticity`
    /// directly, so the raw property stays available unfiltered for anything that needs it.
    nonisolated var witlyVisibleEncryptionAuthenticity: EncryptionAuthenticity? {
        properties.encryptionAuthenticity?.witlyFiltered(senderID: sender.id)
    }
}
