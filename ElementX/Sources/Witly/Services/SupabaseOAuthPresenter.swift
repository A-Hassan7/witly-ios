//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import AuthenticationServices
import UIKit

/// Presents Supabase's Google OAuth consent screen via `ASWebAuthenticationSession`, mirroring the
/// pattern already used for Matrix OAuth in `OAuthAuthenticationPresenter`.
///
/// Google OAuth redirects back to `witly://auth-callback#access_token=…&refresh_token=…&expires_in=…`
/// (the session in the URL fragment, same shape Supabase uses for the web fork). Requires the `witly`
/// URL scheme to be registered in `ElementX/SupportingFiles/target.yml`.
final class SupabaseOAuthPresenter: NSObject {
    private let authService: SupabaseAuthService
    private let presentationAnchor: UIWindow
    
    static let redirectURL = URL(string: "witly://auth-callback")!
    
    init(authService: SupabaseAuthService = SupabaseAuthService(), presentationAnchor: UIWindow) {
        self.authService = authService
        self.presentationAnchor = presentationAnchor
    }
    
    /// Presents the Google consent screen and, on success, resolves the Supabase session.
    func signInWithGoogle() async -> Result<SupabaseSession, SupabaseAuthError> {
        var components = URLComponents(string: "\(WitlyConfig.supabaseURL)/auth/v1/authorize")!
        components.queryItems = [.init(name: "provider", value: "google"),
                                 .init(name: "redirect_to", value: Self.redirectURL.absoluteString)]
        
        let callbackURL: URL?
        do {
            callbackURL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(url: components.url!, callback: .customScheme("witly")) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: url)
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.activeSession = session
                session.start()
            }
        } catch {
            if error.isOAuthUserCancellation {
                return .failure(SupabaseAuthError(message: "cancelled", status: -1))
            }
            WitlyLog.error("Google sign-in session failed: \(error)")
            return .failure(SupabaseAuthError(message: "\(error)", status: -1))
        }
        
        guard let callbackURL, let tokens = Self.parseFragmentTokens(from: callbackURL) else {
            return .failure(SupabaseAuthError(message: "Missing tokens in OAuth callback", status: -1))
        }
        
        do {
            let user = try await authService.currentUser(accessToken: tokens.accessToken)
            return .success(SupabaseSession(accessToken: tokens.accessToken,
                                            refreshToken: tokens.refreshToken,
                                            expiresIn: tokens.expiresIn,
                                            user: user))
        } catch let error as SupabaseAuthError {
            return .failure(error)
        } catch {
            return .failure(SupabaseAuthError(message: "\(error)", status: -1))
        }
    }
    
    // MARK: - Private
    
    private var activeSession: ASWebAuthenticationSession?
    
    /// Google/magic-link redirects carry the session in the URL **fragment**, e.g.
    /// `witly://auth-callback#access_token=…&refresh_token=…&expires_in=…`.
    private static func parseFragmentTokens(from url: URL) -> (accessToken: String, refreshToken: String, expiresIn: Int)? {
        guard let fragment = url.fragment else { return nil }
        let params = fragment.split(separator: "&").reduce(into: [String: String]()) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return }
            result[String(parts[0])] = String(parts[1]).removingPercentEncoding
        }
        guard let accessToken = params["access_token"], let refreshToken = params["refresh_token"] else {
            return nil
        }
        return (accessToken, refreshToken, Int(params["expires_in"] ?? "3600") ?? 3600)
    }
}

extension SupabaseOAuthPresenter: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchor
    }
}
