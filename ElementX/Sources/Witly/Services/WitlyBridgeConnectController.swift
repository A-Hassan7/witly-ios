//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

nonisolated enum WitlyBridgeConnectError: Error, Sendable {
    case failed(String)
    case timedOut
}

/// Ensures a bridge is deployed + registered and ready to accept a login, polling
/// `GET /bridges/{service}/status` after an idempotent `POST /bridges/{service}`.
/// Ported from the web fork's `connectController.ts`.
nonisolated struct WitlyBridgeConnectController: Sendable {
    private let api: AGChatAPIClient
    private let pollInterval: Duration = .seconds(3)
    private let maxAttempts = 40 // ~2 minutes
    
    init(api: AGChatAPIClient) {
        self.api = api
    }
    
    func ensureBridgeReady(service: BridgeService, onProgress: (@Sendable (String) -> Void)? = nil) async throws -> BridgeStatusResponse {
        onProgress?("Setting things up…")
        var status = try await api.postBridge(service: service)
        
        // `postBridge` is idempotent — if a *previous* deploy attempt already failed, it just
        // returns that stale ERROR row forever without retrying. Delete it once and recreate so a
        // "Retry" actually triggers a fresh deployment instead of re-showing the old failure.
        if status.deployStatus == "ERROR" {
            WitlyLog.warning("Bridge \(service.rawValue) was already in ERROR; deleting and redeploying")
            onProgress?("Clearing a stuck connection…")
            try await api.deleteBridge(service: service)
            status = try await api.postBridge(service: service)
        }
        
        for _ in 0..<maxAttempts {
            if status.deployStatus == "ERROR" {
                throw WitlyBridgeConnectError.failed("The connection service failed to start. Please try again.")
            }
            if status.isReadyForLogin {
                return status
            }
            try await Task.sleep(for: pollInterval)
            status = try await api.bridgeStatus(service: service)
        }
        
        throw WitlyBridgeConnectError.timedOut
    }
}
