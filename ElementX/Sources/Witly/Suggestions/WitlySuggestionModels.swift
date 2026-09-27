//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// A single reply suggestion, as rendered in the compact bar above the composer.
nonisolated struct WitlySuggestion: Identifiable, Equatable, Sendable {
    /// Stable within one generation round (the backend's `index`); not stable across rounds.
    let id: Int
    let text: String
    /// The tone/persona label from the backend (e.g. "casual", "banter"). Deliberately not shown
    /// prominently in the UI (see product-spec §7.1 / DRIVE-C4) — kept only for potential future use.
    let tone: String?
}

/// The compact bar's visible state for one room. Mirrors the web engine's `RoomSuggestionState`
/// (`apps/web/src/witly/suggestions/types.ts`), simplified for v1 (no per-Wit multi-source fan-out —
/// see `WitlyRoomSuggestionsViewModel` for why).
nonisolated enum WitlyRoomSuggestionsPhase: Equatable, Sendable {
    /// Nothing to show; the bar renders collapsed (just the ✨ button).
    case idle
    /// A generation is in flight and nothing has arrived yet.
    case generating
    /// 1+ suggestions have arrived and more may still be coming.
    case streaming
    /// The generation finished; `suggestions` won't change until the next round.
    case ready
    /// A retryable failure (network, auth, backend error, or an empty/parse-failed result).
    case error(message: String)
}

nonisolated struct WitlyRoomSuggestionsState: Equatable, Sendable {
    var phase: WitlyRoomSuggestionsPhase = .idle
    var suggestions: [WitlySuggestion] = []
    
    static let idle = WitlyRoomSuggestionsState()
}

/// One recent room message, flattened for the `suggestions/mix` backend contract
/// (`{sender_id, is_own, body}` — see `backend/app/ai/handlers/mix_suggestions.py`). Never logged.
nonisolated struct WitlyContextMessage: Sendable {
    let senderID: String
    let isOwn: Bool
    let body: String
    
    var jsonObject: [String: Any] {
        ["sender_id": senderID, "is_own": isOwn, "body": body]
    }
}
