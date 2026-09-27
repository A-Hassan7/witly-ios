//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Foundation

/// Watches one room's live timeline for genuinely new **inbound** messages and drives the
/// Smart-timing burst debounce, mirroring the web engine's `suggestions/timing.ts` (Manual mode isn't
/// modelled here — v1 is always-on Smart timing; see `WitlyRoomSuggestionsViewModel`).
///
/// This is the only Witly type that touches `TimelineControllerProtocol` directly — kept separate
/// from generation/state so the debounce policy can be reasoned about (and tested) in isolation.
///
/// Guardrails (DRIVE-C3 / product-spec §7.2):
///  - only genuinely new **inbound** items fire generation, never the user's own sends;
///  - a burst of inbound messages resets the debounce timer rather than firing once per message;
///  - typing is never observed here at all, so it can never suppress a fire;
///  - a frequency cap (cooldown) prevents runaway auto-fires in a very chatty room.
@MainActor
final class WitlyRoomTimelineWatcher {
    /// Delay after the last new inbound message before firing a generation.
    static let debounceInterval: Duration = .seconds(5)
    /// Minimum gap between two auto-fires in the same room.
    static let cooldownInterval: TimeInterval = 30
    /// How many recent messages to hand the backend as context.
    static let contextLimit = 40
    
    private let timelineController: TimelineControllerProtocol
    
    private var cancellable: AnyCancellable?
    private var debounceTask: Task<Void, Never>?
    private var lastFireDate: Date?
    private var seenItemIDs: Set<TimelineItemIdentifier>
    /// The newest message timestamp seen so far. Alongside `seenItemIDs`, this is what stops a
    /// backward pagination (loading *older* history into the same array) from being misread as new
    /// activity: paginated-in items are unseen IDs too, but their timestamps are always older than
    /// this watermark, so they never qualify as "new".
    private var latestSeenTimestamp: Date
    
    /// Fires once the debounce window elapses after new inbound activity — time to generate.
    var onShouldGenerate: (() -> Void)?
    /// Fires the instant a new inbound message arrives, even before the debounce completes, so the
    /// caller can invalidate/clear whatever suggestions are currently on screen right away.
    var onNewInboundMessage: (() -> Void)?
    
    init(timelineController: TimelineControllerProtocol) {
        self.timelineController = timelineController
        // Snapshot existing history as "already seen" so opening a room with prior messages never
        // fires a generation on attach — only genuinely new activity should.
        let initialItems = timelineController.timelineItems
        seenItemIDs = Set(initialItems.map(\.id))
        latestSeenTimestamp =
            initialItems.compactMap { ($0 as? EventBasedTimelineItemProtocol)?.timestamp }.max()
                ?? .distantPast
        
        cancellable = timelineController.callbacks.sink { [weak self] callback in
            guard case .updatedTimelineItems(let items, let isSwitchingTimelines) = callback else {
                return
            }
            self?.processUpdate(items: items, isSwitchingTimelines: isSwitchingTimelines)
        }
    }
    
    func stop() {
        cancellable?.cancel()
        debounceTask?.cancel()
    }
    
    /// The most recent text-bearing messages in the room, oldest → newest. Media-only items collapse
    /// to their existing short placeholder body (e.g. a filename), matching how Element itself
    /// summarises them elsewhere — never the raw attachment.
    func recentContext(limit: Int = WitlyRoomTimelineWatcher.contextLimit) -> [WitlyContextMessage] {
        var out: [WitlyContextMessage] = []
        for item in timelineController.timelineItems.reversed() {
            guard let message = item as? EventBasedTimelineItemProtocol, !message.body.isEmpty
            else { continue }
            out.append(WitlyContextMessage(senderID: message.sender.id, isOwn: message.isOutgoing, body: message.body))
            if out.count >= limit {
                break
            }
        }
        return out.reversed()
    }
    
    // MARK: - Private
    
    private func processUpdate(items: [RoomTimelineItemProtocol], isSwitchingTimelines: Bool) {
        defer { seenItemIDs = Set(items.map(\.id)) }
        
        // A full reload (e.g. jumping to a focused/pinned event) isn't new conversation activity.
        guard !isSwitchingTimelines else { return }
        
        var sawNewInbound = false
        var sawNewOwn = false
        var newWatermark = latestSeenTimestamp
        for item in items {
            guard !seenItemIDs.contains(item.id),
                  let message = item as? EventBasedTimelineItemProtocol,
                  message.timestamp > latestSeenTimestamp
            else {
                continue
            }
            newWatermark = max(newWatermark, message.timestamp)
            if message.isOutgoing {
                sawNewOwn = true
            } else if !message.body.isEmpty {
                sawNewInbound = true
            }
        }
        latestSeenTimestamp = newWatermark
        
        if sawNewInbound {
            onNewInboundMessage?()
            scheduleGeneration()
        } else if sawNewOwn {
            // The user replied before Witly fired — the pending suggestion round is moot.
            cancelPendingGeneration()
        }
    }
    
    private func scheduleGeneration() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled, let self else { return }
            
            if let last = lastFireDate, Date().timeIntervalSince(last) < Self.cooldownInterval {
                WitlyLog.info("suggestions: within cooldown, skipping auto-fire")
                return
            }
            lastFireDate = Date()
            onShouldGenerate?()
        }
    }
    
    private func cancelPendingGeneration() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}
