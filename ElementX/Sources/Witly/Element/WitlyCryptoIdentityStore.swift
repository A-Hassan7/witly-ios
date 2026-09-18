//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
@preconcurrency import KeychainAccess

/// The local crypto identity (Olm/crypto store location + its encryption passphrase) used to
/// restore a Matrix session for a given device ID.
nonisolated struct WitlyCryptoIdentity: Codable, Sendable {
    let sessionDirectories: SessionDirectories
    let passphrase: String
}

/// Persists `WitlyCryptoIdentity` per Matrix device ID.
///
/// The AGChat backend hands out the *same* shared `admin_access_token` (and therefore the same
/// homeserver device ID, resolved via `whoami`) every time a user re-provisions — sign-out doesn't
/// invalidate it server-side. If `WitlySessionRestorer` generated a brand-new local crypto identity
/// on every restore anyway, the homeserver would see the existing device's keys silently replaced
/// each time ("Our own device might have been deleted" in the SDK logs), which can wedge identity
/// resolution and hang the app. Reusing the same local crypto material for the same device ID keeps
/// the client and server crypto state consistent across repeated onboarding runs.
struct WitlyCryptoIdentityStore {
    private let keychain: Keychain
    
    init(keychainService: String = "\(InfoPlistReader.main.baseBundleIdentifier).witly.cryptoIdentity") {
        keychain = Keychain(service: keychainService)
    }
    
    /// Returns the persisted identity for `deviceID`, or `nil` if there isn't one or its on-disk
    /// crypto store is no longer present (e.g. the app's data was reset).
    func load(deviceID: String) -> WitlyCryptoIdentity? {
        guard let data = (try? keychain.getData(deviceID)) ?? nil,
              let identity = try? JSONDecoder().decode(WitlyCryptoIdentity.self, from: data),
              identity.sessionDirectories.isNonTransientUserDataValid()
        else {
            return nil
        }
        return identity
    }
    
    func save(_ identity: WitlyCryptoIdentity, deviceID: String) {
        do {
            try keychain.set(JSONEncoder().encode(identity), key: deviceID)
        } catch {
            WitlyLog.error("Failed persisting crypto identity for device \(deviceID): \(error)")
        }
    }
}
