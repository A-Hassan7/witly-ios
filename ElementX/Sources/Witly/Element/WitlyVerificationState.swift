//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension UserIdentityVerificationState {
    /// Resolves the verification state that's safe to show a normal user for `userID`, forcing
    /// recognised bridge ghosts to `.notVerified` regardless of what the SDK reports.
    ///
    /// Bridge ghosts (e.g. WhatsApp contacts) never have a genuine Matrix cross-signing identity —
    /// any other state the SDK might report for one (including `.verificationViolation`, which the
    /// SDK can only derive from an identity that existed and then changed) isn't meaningful here and
    /// would otherwise surface a "verify this user"/"withdraw verification" prompt that makes no
    /// sense for a bridged contact. `.notVerified` is also what `VerificationBadge` renders as no
    /// badge at all, so this is sufficient to hide the badge too.
    nonisolated static func witlyEffective(for userID: String, identity: UserIdentityProxyProtocol?)
        -> UserIdentityVerificationState {
        if WitlyBridgeIdentity.isBridgeGhost(userID: userID) {
            return .notVerified
        }
        return identity?.verificationState ?? .notVerified
    }
}
