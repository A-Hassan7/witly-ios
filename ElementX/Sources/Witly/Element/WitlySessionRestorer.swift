//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import MatrixRustSDK

enum WitlySessionRestoreError: Error {
    case failedRestoringSession(Error)
    case failedBuildingUserSession(UserSessionStoreError)
}

/// Restores an AGChat-provisioned Matrix session into the Rust SDK and produces an Element
/// `UserSession`, so Witly onboarding can hand back to `AppCoordinator` via the same
/// `didLoginWithSession` delegate Element's own auth flow uses.
///
/// This is the critical iP1 handoff. It deliberately uses **only** public Element APIs (no core edit
/// to the client layer): it builds a `Session` from the provisioned credentials, then reuses
/// `ClientFactory.makeAppClient` (which runs `restoreSessionWith` and invokes
/// `appHooks.clientFactoryHook`) and `UserSessionStore.userSession(for:…)` (which persists the
/// keychain `RestorationToken`). Restoring directly sidesteps `login()`'s "non-OAuth session with a
/// refresh token" rejection — our `Session` carries no refresh token and no OAuth data.
struct WitlySessionRestorer {
    private let clientFactory: ClientFactoryProtocol
    private let userSessionStore: UserSessionStoreProtocol
    private let encryptionKeyProvider: EncryptionKeyProviderProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks
    
    init(userSessionStore: UserSessionStoreProtocol,
         appSettings: AppSettings,
         appHooks: AppHooks,
         clientFactory: ClientFactoryProtocol = ClientFactory(),
         encryptionKeyProvider: EncryptionKeyProviderProtocol = EncryptionKeyProvider()) {
        self.userSessionStore = userSessionStore
        self.appSettings = appSettings
        self.appHooks = appHooks
        self.clientFactory = clientFactory
        self.encryptionKeyProvider = encryptionKeyProvider
    }
    
    func restore(credentials: WitlyMatrixCredentials) async -> Result<UserSessionProtocol, WitlySessionRestoreError> {
        let session = Session(accessToken: credentials.accessToken,
                              refreshToken: nil,
                              userId: credentials.userID,
                              deviceId: credentials.deviceID,
                              homeserverUrl: credentials.homeserverURL,
                              oauthData: nil,
                              slidingSyncVersion: .native)
        
        let sessionDirectories = SessionDirectories()
        let passphrase = encryptionKeyProvider.generateKey().base64EncodedString()
        
        let restorationToken = RestorationToken(session: session,
                                                sessionDirectories: sessionDirectories,
                                                passphrase: passphrase,
                                                pusherNotificationClientIdentifier: nil)
        let keychainCredentials = KeychainCredentials(userID: credentials.userID, restorationToken: restorationToken)
        
        do {
            WitlyLog.info("Restoring provisioned Matrix session for \(credentials.userID)")
            let client = try await clientFactory.makeAppClient(credentials: keychainCredentials,
                                                               clientSessionDelegate: userSessionStore.clientSessionDelegate,
                                                               appSettings: appSettings,
                                                               appHooks: appHooks)
            
            switch await userSessionStore.userSession(for: client, sessionDirectories: sessionDirectories, passphrase: passphrase) {
            case .success(let userSession):
                WitlyLog.info("Provisioned session restored; user session ready")
                return .success(userSession)
            case .failure(let error):
                WitlyLog.error("Failed building user session from restored client: \(error)")
                return .failure(.failedBuildingUserSession(error))
            }
        } catch {
            WitlyLog.error("Failed restoring provisioned session: \(error)")
            return .failure(.failedRestoringSession(error))
        }
    }
}
