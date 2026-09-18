//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
@preconcurrency import KeychainAccess

/// The persisted Witly (Supabase) session — the single holder of the user's backend auth tokens.
nonisolated struct WitlySessionData: Sendable, Codable {
    var supabaseToken: String
    var supabaseRefreshToken: String
    /// Epoch seconds when the access token expires.
    var supabaseTokenExpiresAt: TimeInterval
    var userId: String
    var email: String?
}

/// Holds the Supabase auth tokens and hands out a valid access token, refreshing proactively near
/// expiry. Ported from the web fork's `session.ts`.
///
/// Crucially this lives in its **own** keychain service, independent of Element's Matrix
/// `RestorationToken`, so a Matrix re-auth/logout never drops the Witly (backend) identity — the app
/// can then silently re-provision Matrix (plan §5 durability). Does **not** hold the Matrix session.
actor WitlySession {
    private let authService: SupabaseAuthService
    private let keychain: Keychain
    private static let storageKey = "session"
    
    private var data: WitlySessionData?
    /// Refresh when fewer than this many seconds remain on the access token.
    private let refreshThreshold: TimeInterval = 60
    
    init(authService: SupabaseAuthService = SupabaseAuthService(),
         keychainService: String = "\(InfoPlistReader.main.baseBundleIdentifier).witly.session") {
        self.authService = authService
        keychain = Keychain(service: keychainService)
        data = Self.load(from: keychain)
    }
    
    var isAuthenticated: Bool {
        data != nil
    }
    
    var userID: String? {
        data?.userId
    }
    
    /// Populate the session from a completed Supabase authentication and persist it.
    func establish(from session: SupabaseSession) {
        set(WitlySessionData(supabaseToken: session.accessToken,
                             supabaseRefreshToken: session.refreshToken,
                             supabaseTokenExpiresAt: Date().timeIntervalSince1970
                                 + TimeInterval(session.expiresIn),
                             userId: session.user.id,
                             email: session.user.email))
    }
    
    /// A valid access token, refreshing first if it's within the refresh threshold of expiry.
    func validToken() async throws -> String {
        guard let current = data else {
            throw SupabaseAuthError(message: "Not authenticated", status: 401)
        }
        if Date().timeIntervalSince1970 >= current.supabaseTokenExpiresAt - refreshThreshold {
            return try await forceRefresh()
        }
        return current.supabaseToken
    }
    
    /// Refresh the access token now. Clears the session only on a **definitive** rejection (a used or
    /// invalid refresh token — 400/401); a transient failure preserves the session so a network blip
    /// doesn't sign the user out.
    @discardableResult
    func forceRefresh() async throws -> String {
        guard let current = data else {
            throw SupabaseAuthError(message: "Not authenticated", status: 401)
        }
        do {
            let refreshed = try await authService.refreshSession(refreshToken: current.supabaseRefreshToken)
            establish(from: refreshed)
            return refreshed.accessToken
        } catch let error as SupabaseAuthError where error.status == 400 || error.status == 401 {
            WitlyLog.warning("Supabase refresh definitively rejected (\(error.status)); clearing session")
            clear()
            throw error
        } catch {
            WitlyLog.warning("Supabase refresh failed transiently; keeping session: \(error)")
            throw error
        }
    }
    
    func clear() {
        data = nil
        try? keychain.remove(Self.storageKey)
    }
    
    // MARK: - Private
    
    private func set(_ newData: WitlySessionData) {
        data = newData
        do {
            try keychain.set(JSONEncoder().encode(newData), key: Self.storageKey)
        } catch {
            WitlyLog.error("Failed persisting Witly session: \(error)")
        }
    }
    
    private static func load(from keychain: Keychain) -> WitlySessionData? {
        guard let raw = (try? keychain.getData(storageKey)) ?? nil else { return nil }
        return try? JSONDecoder().decode(WitlySessionData.self, from: raw)
    }
}
