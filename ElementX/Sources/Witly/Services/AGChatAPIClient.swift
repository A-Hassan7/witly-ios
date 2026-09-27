//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

nonisolated enum ProvisionStatus: String, Sendable, Codable {
    case provisioning = "PROVISIONING"
    case ready = "READY"
    case error = "ERROR"
}

/// Response of the provisioning endpoints. Field names match the backend 1:1.
nonisolated struct ProvisionStatusResponse: Sendable, Codable {
    let homeserverId: String
    let status: ProvisionStatus
    let doublepuppetRegistered: Bool
    let serverName: String?
    let homeserverUrl: String?
    let matrixUserId: String?
    let matrixAccessToken: String?
    
    enum CodingKeys: String, CodingKey {
        case homeserverId = "homeserver_id"
        case status
        case doublepuppetRegistered = "doublepuppet_registered"
        case serverName = "server_name"
        case homeserverUrl = "homeserver_url"
        case matrixUserId = "matrix_user_id"
        case matrixAccessToken = "matrix_access_token"
    }
}

nonisolated struct AGChatAPIError: Error, Sendable {
    let status: Int
    let detail: String
}

// MARK: - AI suggestions

/// Body for `POST /suggestions`. `variables` is untyped JSON (feature-specific), so it's carried as
/// `[String: Any]` and encoded manually rather than via `Encodable` (see `request(_:method:body:)`).
nonisolated struct SuggestionsResponse: Sendable, Codable {
    let taskId: String
    let streamKey: String
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case streamKey = "stream_key"
        case requestId = "request_id"
    }
}

// MARK: - Bridges

nonisolated enum BridgeService: String, Sendable, Codable {
    case whatsapp
    case meta
    case telegram
}

/// Live remote-network connectivity, refreshed by the backend's health worker (~60s, or ~5s while
/// a bridge is still provisioning/logging in) from the bridge's own `whoami`. Distinct from
/// `loginStatus` (the control-plane's record of the login *flow*) — `remoteState` is the ongoing
/// health/connectivity signal once a login exists. `NOT_PROVISIONED` is the default for any bridge
/// that isn't deployed/registered yet and is not an error state.
nonisolated enum BridgeRemoteState: String, Sendable, Codable {
    case notProvisioned = "NOT_PROVISIONED"
    case loggedOut = "LOGGED_OUT"
    case connected = "CONNECTED"
    case backfilling = "BACKFILLING"
    case transientDisconnect = "TRANSIENT_DISCONNECT"
    case badCredentials = "BAD_CREDENTIALS"
}

nonisolated struct BridgeStatusResponse: Sendable, Codable {
    let bridgeId: String
    let service: BridgeService
    let deployStatus: String
    let registrationStatus: String
    let loginStatus: String
    let remoteState: BridgeRemoteState
    /// The last time `remoteState` was *successfully* refreshed — if the bridge becomes
    /// unreachable, `remoteState` is left at its last-known value rather than reset, so check this
    /// for staleness before trusting it after a long gap. `nil` if it's never been checked.
    let remoteStateCheckedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case bridgeId = "bridge_id"
        case service
        case deployStatus = "deploy_status"
        case registrationStatus = "registration_status"
        case loginStatus = "login_status"
        case remoteState = "remote_state"
        case remoteStateCheckedAt = "remote_state_checked_at"
    }
    
    var isReadyForLogin: Bool {
        deployStatus == "READY" && registrationStatus == "REGISTERED"
    }
}

nonisolated struct LoginStepField: Sendable, Codable {
    let type: String
    let id: String
    let name: String
    let description: String?
}

nonisolated struct LoginStepUserInput: Sendable, Codable {
    let fields: [LoginStepField]
}

nonisolated struct LoginStepDisplayAndWait: Sendable, Codable {
    let type: String
    /// The raw pairing code (or QR string) to show the user.
    let data: String?
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
        case imageUrl = "image_url"
    }
}

/// Matches the mautrix bridgev2 provisioning API's `LoginStep` shape.
nonisolated struct LoginStep: Sendable, Codable {
    let loginId: String?
    let stepId: String
    let type: String // "user_input" | "display_and_wait" | "cookies" | "complete"
    let instructions: String?
    let displayAndWait: LoginStepDisplayAndWait?
    let userInput: LoginStepUserInput?
    
    enum CodingKeys: String, CodingKey {
        case loginId = "login_id"
        case stepId = "step_id"
        case type
        case instructions
        case displayAndWait = "display_and_wait"
        case userInput = "user_input"
    }
}

/// Typed client for the AGChat control-plane API, ported from the web fork's `agchatApi.ts`.
///
/// Auth: bearer Supabase token from `WitlySession`; on a 401 it forces a token refresh and retries
/// once (server-side invalidation / clock skew). The endpoint surface is unchanged from web —
/// provisioning, bridges, and the `POST /suggestions` AI entry point are exposed here; the SSE
/// stream itself is read separately via `WitlyAIStreamClient` (`GET /ai/stream/{stream_key}` is
/// unauthenticated — a capability token in the URL — so it doesn't go through `request(_:)`).
nonisolated struct AGChatAPIClient: Sendable {
    private let session: WitlySession
    private let urlSession: URLSession
    private var baseURL: String {
        WitlyConfig.apiBase
    }
    
    init(session: WitlySession, urlSession: URLSession = .shared) {
        self.session = session
        self.urlSession = urlSession
    }
    
    // MARK: - Provision
    
    func startProvision() async throws -> ProvisionStatusResponse {
        try await request("/provision", method: "POST")
    }
    
    func provisionStatus() async throws -> ProvisionStatusResponse {
        try await request("/provision/status", method: "GET")
    }
    
    func deleteProvision() async throws {
        let _: EmptyResponse = try await request("/provision", method: "DELETE")
    }
    
    // MARK: - AI
    
    /// Kick off an AI generation request. `variables` is feature-specific untyped JSON (e.g.
    /// `["messages": [["sender_id": ..., "is_own": ..., "body": ...], ...]]` for `suggestions/mix`).
    /// The response's `streamKey` is then read via `WitlyAIStreamClient` — this call only enqueues
    /// the generation, it does not itself return suggestions.
    func postSuggestions(feature: String, variables: [String: Any], version: String? = nil,
                         roomId: String? = nil) async throws -> SuggestionsResponse {
        var body: [String: Any] = ["feature": feature, "variables": variables]
        if let version {
            body["version"] = version
        }
        if let roomId {
            body["room_id"] = roomId
        }
        return try await request("/suggestions", method: "POST", body: body)
    }
    
    // MARK: - Bridges
    
    /// Deploy (idempotent) the bridge for `service`. Returns 200 if already active, 202 if newly created.
    func postBridge(service: BridgeService) async throws -> BridgeStatusResponse {
        try await request("/bridges/\(service.rawValue)", method: "POST")
    }
    
    func bridgeStatus(service: BridgeService) async throws -> BridgeStatusResponse {
        try await request("/bridges/\(service.rawValue)/status", method: "GET")
    }
    
    /// Soft-delete the bridge row and its K8s resources so a fresh `postBridge` can redeploy it.
    /// Runs several sequential remote calls server-side (unregister, k8s delete), so allow longer than the default.
    func deleteBridge(service: BridgeService) async throws {
        let _: EmptyResponse = try await request("/bridges/\(service.rawValue)", method: "DELETE", timeout: 60)
    }
    
    /// Start a login flow (e.g. `flowId: "phone"` for WhatsApp) and return the first step.
    func startBridgeLogin(service: BridgeService, flowId: String) async throws -> LoginStep {
        try await request("/bridges/\(service.rawValue)/login/start", method: "POST",
                          body: ["flow_id": flowId])
    }
    
    /// Submit data for the current step and advance the flow. `data: [:]` for `display_and_wait`, which
    /// long-polls server-side for up to 180s until the user completes the action on their device.
    func submitBridgeLoginStep(service: BridgeService, loginId: String, stepId: String, stepType: String,
                               data: [String: String]) async throws -> LoginStep {
        let timeout: TimeInterval = stepType == "display_and_wait" ? 185 : 30
        return try await request("/bridges/\(service.rawValue)/login/\(loginId)/step", method: "POST",
                                 body: ["step_id": stepId, "step_type": stepType, "data": data] as [String: Any],
                                 timeout: timeout)
    }
    
    // MARK: - Request helper
    
    private func request<T: Decodable>(_ path: String, method: String, body: [String: Any]? = nil,
                                       timeout: TimeInterval = 30, retried: Bool = false) async throws -> T {
        let token = try await session.validToken()
        
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw AGChatAPIError(status: -1, detail: "The server took too long to respond. Please try again.")
        }
        guard let http = response as? HTTPURLResponse else {
            throw AGChatAPIError(status: -1, detail: "No HTTP response")
        }
        
        // On 401: force a refresh and retry once (server-side invalidation / skew).
        if http.statusCode == 401, !retried {
            WitlyLog.warning("401 on \(path) — refreshing token and retrying")
            _ = try await session.forceRefresh()
            return try await self.request(path, method: method, body: body, timeout: timeout, retried: true)
        }
        
        guard (200..<300).contains(http.statusCode) else {
            throw AGChatAPIError(status: http.statusCode, detail: extractDetail(data, fallback: "\(http.statusCode)"))
        }
        
        if http.statusCode == 204 || data.isEmpty {
            return try Self.jsonDecoder.decode(T.self, from: Data("{}".utf8))
        }
        return try Self.jsonDecoder.decode(T.self, from: data)
    }
    
    /// The backend emits naive (no timezone suffix) UTC timestamps, e.g. `remote_state_checked_at`
    /// (Python's `datetime.isoformat()`), which Foundation's default/`.iso8601` strategies can't
    /// parse (they require a timezone). Try with-fractional-seconds first, then without.
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let withFractional = DateFormatter()
        withFractional.locale = Locale(identifier: "en_US_POSIX")
        withFractional.timeZone = TimeZone(identifier: "UTC")
        withFractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        
        let withoutFractional = DateFormatter()
        withoutFractional.locale = Locale(identifier: "en_US_POSIX")
        withoutFractional.timeZone = TimeZone(identifier: "UTC")
        withoutFractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFractional.date(from: string) ?? withoutFractional.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date format: \(string)")
        }
        return decoder
    }()
    
    private func extractDetail(_ data: Data, fallback: String) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = object["detail"] as? String
        else {
            return fallback
        }
        return detail
    }
}

/// Decodes an empty/`204` body for endpoints that return no content.
private struct EmptyResponse: Decodable { }
