//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// The Matrix credentials produced by provisioning, ready to hydrate a Rust SDK session.
nonisolated struct WitlyMatrixCredentials: Sendable {
    let userID: String
    let accessToken: String
    let homeserverURL: String
    /// Resolved via `whoami`, or a stable fallback if the homeserver didn't return one.
    let deviceID: String
}

nonisolated enum WitlyProvisioningError: Error, Sendable {
    case failed
    case timedOut
    case missingCredentials
}

/// Drives homeserver provisioning → Matrix credentials, ported from the web fork's `provisioning.ts`.
///
/// `POST /provision` is idempotent (returns the existing homeserver or starts one), then we poll
/// `GET /provision/status` until `READY`. The status response omits the device ID, so — like web — we
/// resolve it via `/_matrix/client/v3/account/whoami`, falling back to a placeholder the homeserver
/// still accepts (the Rust SDK also settles the device ID during session restore).
nonisolated struct WitlyProvisioning: Sendable {
    private let api: AGChatAPIClient
    private let urlSession: URLSession
    
    private let pollInterval: Duration = .seconds(3)
    private let maxAttempts = 60 // ~3 minutes
    private static let deviceIDFallback = "WITLY_IOS"
    
    init(api: AGChatAPIClient, urlSession: URLSession = .shared) {
        self.api = api
        self.urlSession = urlSession
    }
    
    /// Kick off provisioning (idempotent) and poll until READY, resolving Matrix credentials.
    func provision() async throws -> WitlyMatrixCredentials {
        WitlyLog.info("Starting provisioning")
        var status = try await api.startProvision()
        WitlyLog.info("provision POST returned status=\(status.status.rawValue)")
        
        if status.status == .ready {
            return try await resolveCredentials(status)
        }
        
        for attempt in 0..<maxAttempts {
            try await Task.sleep(for: pollInterval)
            status = try await api.provisionStatus()
            
            switch status.status {
            case .ready:
                WitlyLog.info("Provisioning READY after \(attempt + 1) poll(s)")
                return try await resolveCredentials(status)
            case .error:
                throw WitlyProvisioningError.failed
            case .provisioning:
                continue
            }
        }
        
        throw WitlyProvisioningError.timedOut
    }
    
    /// Poll the current provisioning status without kicking off a new provision.
    func currentStatus() async throws -> ProvisionStatusResponse {
        try await api.provisionStatus()
    }
    
    // MARK: - Private
    
    private func resolveCredentials(_ status: ProvisionStatusResponse) async throws
        -> WitlyMatrixCredentials {
        guard let userID = status.matrixUserId,
              let accessToken = status.matrixAccessToken,
              let homeserverURL = status.homeserverUrl
        else {
            throw WitlyProvisioningError.missingCredentials
        }
        
        let deviceID =
            await fetchDeviceID(homeserverURL: homeserverURL, accessToken: accessToken)
                ?? Self.deviceIDFallback
        WitlyLog.info("Homeserver READY at \(homeserverURL); deviceID=\(deviceID)")
        
        return WitlyMatrixCredentials(userID: userID,
                                      accessToken: accessToken,
                                      homeserverURL: homeserverURL,
                                      deviceID: deviceID)
    }
    
    private func fetchDeviceID(homeserverURL: String, accessToken: String) async -> String? {
        let base = homeserverURL.hasSuffix("/") ? String(homeserverURL.dropLast()) : homeserverURL
        guard let url = URL(string: "\(base)/_matrix/client/v3/account/whoami") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                WitlyLog.warning("whoami failed; continuing without deviceID")
                return nil
            }
            return object["device_id"] as? String
        } catch {
            WitlyLog.warning("whoami request failed; continuing without deviceID: \(error)")
            return nil
        }
    }
}
