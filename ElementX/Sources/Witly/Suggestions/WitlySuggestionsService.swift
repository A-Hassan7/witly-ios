//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Generates in-room reply suggestions via the shared AGChat AI contract (`POST /suggestions` +
/// `GET /ai/stream/{stream_key}` SSE) — the same primitive the web client uses for both in-room
/// suggestions and Ask AI (`docs/project/FRONTEND_CONTEXT.md` §6).
///
/// v1 always uses the `suggestions/mix` feature, the backend's zero-config "default mix" handler
/// (a single LLM call returning several tone-varied replies) — this matches product-spec's DRIVE-C2
/// ("no mandatory Wit selection; default zero-config 'Me + Wittier'"). There is no Wit mix / custom
/// Wit / Wildcard fan-out here (unlike the web engine's per-source multi-call `suggestionStore.ts`) —
/// that's explicitly out of scope for this task (Wit Library / custom Wits UI) and iOS has no wit-mix
/// storage yet (`docs/witly/parity-ledger.md` §2/§4). Swap the feature/variables here, not the
/// call sites, if/when Wit-mix support lands on iOS.
nonisolated struct WitlySuggestionsService: Sendable {
    private static let feature = "suggestions/mix"
    
    private let apiClient: AGChatAPIClient
    private let streamClient: WitlyAIStreamClient
    
    init(apiClient: AGChatAPIClient, streamClient: WitlyAIStreamClient = WitlyAIStreamClient()) {
        self.apiClient = apiClient
        self.streamClient = streamClient
    }
    
    /// Enqueues one generation round for `context` and returns its live SSE event stream.
    /// Throws only on a genuine request failure (auth, network, validation, credits) — a stream that
    /// opens successfully never throws for a backend-reported failure (see `.serverError`).
    func generate(context: [WitlyContextMessage], roomID: String) async throws -> AsyncThrowingStream<WitlyAIStreamEvent, Error> {
        let variables: [String: Any] = ["messages": context.map(\.jsonObject)]
        let response = try await apiClient.postSuggestions(feature: Self.feature, variables: variables, roomId: roomID)
        return streamClient.stream(streamKey: response.streamKey)
    }
}
