//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Foundation

/// Per-room state/orchestration for the in-room Witly suggestion bar. One instance per
/// `RoomScreenCoordinator` (i.e. per open room), constructed and torn down alongside it, so leaving
/// or switching rooms can never leak a previous room's suggestions or generation into a new one.
///
/// Owns three separate concerns (kept in their own types on purpose — see
/// `ElementX/Sources/Witly/AGENTS.md`):
///  - **room/timeline observation** → `WitlyRoomTimelineWatcher`
///  - **generation + streaming** → `WitlySuggestionsService` (→ `WitlyAIStreamClient`)
///  - **per-room UI state** → `self`, published for the SwiftUI bar to render
///
/// **Hard requirement (this task's spec): a Witly failure must never become a chat failure.** Every
/// public entry point here is non-throwing; every internal failure funnels into `.error(message)`
/// and is logged (without message contents) rather than propagated.
@MainActor
final class WitlyRoomSuggestionsViewModel: ObservableObject {
    @Published private(set) var state: WitlyRoomSuggestionsState = .idle
    
    private let roomID: String
    private let watcher: WitlyRoomTimelineWatcher
    private let service: WitlySuggestionsService
    private var generationTask: Task<Void, Never>?
    
    /// Inserts `text` into the room's composer as an editable draft (never sends). Wired by
    /// `RoomScreenCoordinator` to its existing `shareText(_:)` (replace-draft + focus) — see
    /// `PATCHES.md` for why this reuses that method rather than adding a new composer core seam.
    var onInsertSuggestion: ((String) -> Void)?
    /// The ✨ button's action: opens the deeper Witly surface. No panel exists yet in this task's
    /// scope, so `RoomScreenCoordinator` wires this to a lightweight "coming soon" indicator — a
    /// clean, stable integration point to swap for `presentWitlyPanel` later (see
    /// `docs/witly/parity-ledger.md` §8's iOS seam notes).
    var onOpenWitly: (() -> Void)?
    
    init(roomID: String, timelineController: TimelineControllerProtocol, apiClient: AGChatAPIClient) {
        self.roomID = roomID
        WitlyLog.info("suggestions: watching room \(roomID)")
        watcher = WitlyRoomTimelineWatcher(timelineController: timelineController)
        service = WitlySuggestionsService(apiClient: apiClient)
        
        watcher.onNewInboundMessage = { [weak self] in
            // Invalidate immediately — don't wait for the debounce to also clear stale cards.
            self?.invalidateForNewMessage()
        }
        watcher.onShouldGenerate = { [weak self] in
            self?.generate()
        }
    }
    
    func stop() {
        generationTask?.cancel()
        generationTask = nil
        watcher.stop()
    }
    
    /// User-initiated regenerate (refresh icon) or retry-from-error. Always allowed, regardless of
    /// the Smart-timing debounce/cooldown state — those guardrails only gate *automatic* firing.
    func regenerate() {
        WitlyLog.info("suggestions: regenerate requested for room \(roomID)")
        generate()
    }
    
    func insertSuggestion(_ suggestion: WitlySuggestion) {
        WitlyLog.info("suggestions: inserted suggestion #\(suggestion.id) into composer")
        onInsertSuggestion?(suggestion.text)
    }
    
    func openWitly() {
        WitlyLog.verbose("suggestions: ✨ button tapped")
        onOpenWitly?()
    }
    
    // MARK: - Private
    
    private func invalidateForNewMessage() {
        generationTask?.cancel()
        generationTask = nil
        state = .idle
    }
    
    private func generate() {
        generationTask?.cancel()
        state = WitlyRoomSuggestionsState(phase: .generating, suggestions: [])
        
        let context = watcher.recentContext()
        WitlyLog.info("suggestions: generating for room \(roomID) (context: \(context.count) messages)")
        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try await service.generate(context: context, roomID: roomID)
                var received: [WitlySuggestion] = []
                for try await event in stream {
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .suggestion(let index, let text, let tone):
                        WitlyLog.verbose("suggestions: received suggestion #\(index) (tone: \(tone ?? "none"))")
                        received.append(WitlySuggestion(id: index, text: text, tone: tone))
                        state = WitlyRoomSuggestionsState(phase: .streaming, suggestions: received)
                    case .done:
                        WitlyLog.info("suggestions: generation done for room \(roomID) (\(received.count) suggestions)")
                        if received.isEmpty {
                            state = WitlyRoomSuggestionsState(phase: .error(message: "No suggestions this time."), suggestions: [])
                        } else {
                            state = WitlyRoomSuggestionsState(phase: .ready, suggestions: received)
                        }
                    case .serverError(let code, _):
                        WitlyLog.warning("suggestions: backend reported error (code: \(code))")
                        state = WitlyRoomSuggestionsState(phase: .error(message: Self.friendlyMessage(for: code)), suggestions: [])
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                WitlyLog.warning("suggestions: generation failed: \(type(of: error))")
                let message =
                    (error as? AGChatAPIError)?.status == 402
                        ? "You're out of AI credits for now."
                        : "Couldn't get suggestions right now."
                state = WitlyRoomSuggestionsState(phase: .error(message: message), suggestions: [])
            }
        }
    }
    
    /// Never surface raw backend error strings verbatim (they're written for logs/admins, e.g.
    /// "credit_exceeded" codes) — map to one short, non-technical line.
    private static func friendlyMessage(for code: String) -> String {
        code == "credit_exceeded"
            ? "You're out of AI credits for now." : "Couldn't get suggestions right now."
    }
}
