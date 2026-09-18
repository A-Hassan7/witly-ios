//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// A Supabase auth session, matching the Supabase Auth REST response.
nonisolated struct SupabaseSession: Sendable, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: SupabaseUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

nonisolated struct SupabaseUser: Sendable, Codable {
    let id: String
    let email: String?
    let phone: String?
}

/// Carries the HTTP status so callers can distinguish a definitive rejection (400/401 — the session
/// is truly dead) from a transient network/server error that must NOT destroy the session.
nonisolated struct SupabaseAuthError: Error, Sendable {
    let message: String
    let status: Int
}

/// Thin wrappers around the Supabase Auth REST API (no Supabase SDK), ported 1:1 from the web fork's
/// `supabaseAuth.ts`. Google OAuth is handled separately by `SupabaseOAuthSession`
/// (`ASWebAuthenticationSession`); this type covers email/phone OTP + the token lifecycle.
nonisolated struct SupabaseAuthService: Sendable {
    private let urlSession: URLSession
    private var baseURL: String {
        WitlyConfig.supabaseURL
    }
    
    private var apiKey: String {
        WitlyConfig.supabaseKey
    }
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - Token lifecycle
    
    func refreshSession(refreshToken: String) async throws -> SupabaseSession {
        try await postForSession("/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": refreshToken])
    }
    
    func currentUser(accessToken: String) async throws -> SupabaseUser {
        try await get("/auth/v1/user", accessToken: accessToken)
    }
    
    // MARK: - Email magic-link / OTP
    
    /// Send a passwordless email OTP (also creates the account on first use).
    func sendEmailOTP(email: String, redirectTo: String?) async throws {
        var body: [String: Any] = ["email": email, "create_user": true]
        if let redirectTo {
            body["options"] = ["email_redirect_to": redirectTo]
        }
        try await postVoid("/auth/v1/otp", body: body)
    }
    
    func verifyEmailOTP(email: String, token: String) async throws -> SupabaseSession {
        try await postForSession("/auth/v1/verify", body: ["type": "email", "email": email, "token": token])
    }
    
    // MARK: - Phone / SMS OTP (account sign-in — NOT the WhatsApp pairing flow)
    
    func sendPhoneOTP(phone: String) async throws {
        try await postVoid("/auth/v1/otp", body: ["phone": phone, "create_user": true])
    }
    
    func verifyPhoneOTP(phone: String, token: String) async throws -> SupabaseSession {
        try await postForSession("/auth/v1/verify", body: ["type": "sms", "phone": phone, "token": token])
    }
    
    // MARK: - Sign out
    
    func signOut(accessToken: String) async {
        var request = URLRequest(url: url("/auth/v1/logout"))
        request.httpMethod = "POST"
        applyHeaders(&request)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await urlSession.data(for: request)
    }
    
    // MARK: - Request helpers
    
    private func url(_ path: String) -> URL {
        // Paths may include a query string; URL(string:) handles that.
        URL(string: baseURL + path)!
    }
    
    private func applyHeaders(_ request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The publishable key identifies the project; it's public by design (RLS gates data).
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
    }
    
    private func postForSession(_ path: String, body: [String: Any]) async throws -> SupabaseSession {
        let data = try await post(path, body: body)
        return try JSONDecoder().decode(SupabaseSession.self, from: data)
    }
    
    private func postVoid(_ path: String, body: [String: Any]) async throws {
        _ = try await post(path, body: body)
    }
    
    @discardableResult
    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        applyHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        try validate(response, data: data)
        return data
    }
    
    private func get<T: Decodable>(_ path: String, accessToken: String) async throws -> T {
        var request = URLRequest(url: url(path))
        applyHeaders(&request)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await urlSession.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseAuthError(message: "No HTTP response", status: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseAuthError(message: extractError(data, fallback: "\(http.statusCode)"), status: http.statusCode)
        }
    }
    
    private func extractError(_ data: Data, fallback: String) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return fallback
        }
        for key in ["error_description", "msg", "error", "message"] {
            if let value = object[key] as? String {
                return value
            }
        }
        return fallback
    }
}
