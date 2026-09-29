//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Persists the user's response-style control selections (Boldness/Flirt/Bluntness/Dryness) to
/// Matrix account data, so they survive reopening a conversation and sync across devices via the
/// user's own homeserver — mirroring the web client's `witStore.ts` `witly.room_settings` pattern
/// (global default + optional per-room override, one combined event rather than per-room account
/// data, see `PATCHES.md`).
///
/// Content shape (`witly.style_controls` global account data event):
/// ```json
/// { "global": { "boldness": "high" }, "rooms": { "!roomid:server": { "boldness": "low" } } }
/// ```
///
/// A room with no entry in `rooms` inherits `global` entirely — "Me + Wittier by default, tuned for
/// this person when the user wants it."
@MainActor
final class WitlyStyleControlsStore: ObservableObject {
    static let accountDataEventType = "witly.style_controls"
    
    private struct Content: Codable {
        var global: [String: String]
        var rooms: [String: [String: String]]
    }
    
    private let clientProxy: ClientProxyProtocol
    @Published private(set) var global: [String: String] = [:]
    @Published private(set) var rooms: [String: [String: String]] = [:]
    private var isLoaded = false
    
    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
    }
    
    /// Reads the current account data once. Safe to call repeatedly — only the first call actually
    /// hits the client; later calls are a no-op so opening the panel multiple times doesn't re-fetch.
    func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true
        
        switch await clientProxy.witlyAccountDataEvent(eventType: Self.accountDataEventType) {
        case .success(let json):
            guard let json, let data = json.data(using: .utf8),
                  let content = try? JSONDecoder().decode(Content.self, from: data)
            else { return }
            global = content.global
            rooms = content.rooms
        case .failure(let error):
            WitlyLog.warning("style controls: failed reading account data: \(error)")
        }
    }
    
    /// The effective selections for `roomID`: the per-room override merged on top of the global
    /// default (a room with no override inherits the global value for every control).
    func effectiveValues(forRoom roomID: String) -> [String: String] {
        var values = global
        if let override = rooms[roomID] {
            values.merge(override) { _, roomValue in roomValue }
        }
        return values
    }
    
    func hasOverride(forRoom roomID: String) -> Bool {
        rooms[roomID] != nil
    }
    
    /// Turns on per-chat customization for `roomID` without changing any values yet — an explicit
    /// step so the Settings toggle has something concrete to flip on before the user edits a
    /// control. A no-op if the room already has an override.
    func enableOverride(forRoom roomID: String) async {
        guard rooms[roomID] == nil else { return }
        rooms[roomID] = [:]
        let succeeded = await persist()
        if !succeeded {
            rooms[roomID] = nil
        }
    }
    
    /// Sets one control's global default value.
    func setGlobal(controlID: String, optionID: String) async {
        let previous = global[controlID]
        global[controlID] = optionID
        let succeeded = await persist()
        if !succeeded {
            global[controlID] = previous
        }
    }
    
    /// Sets one control's value for `roomID` only, without touching the global default or other rooms.
    func setRoomOverride(roomID: String, controlID: String, optionID: String) async {
        let previous = rooms[roomID]?[controlID]
        var override = rooms[roomID] ?? [:]
        override[controlID] = optionID
        rooms[roomID] = override
        let succeeded = await persist()
        if !succeeded {
            rooms[roomID]?[controlID] = previous
        }
    }
    
    /// Clears every per-room override for `roomID`, so it goes back to inheriting the global default.
    func resetRoom(_ roomID: String) async {
        guard let previous = rooms[roomID] else { return }
        rooms[roomID] = nil
        let succeeded = await persist()
        if !succeeded {
            rooms[roomID] = previous
        }
    }
    
    /// Writes the current `global`/`rooms` state to account data. Returns whether it succeeded, so
    /// callers can roll their optimistic in-memory update back on failure rather than leaving the
    /// UI (and any subsequent generation request) reflecting a value that was never actually saved.
    @discardableResult
    private func persist() async -> Bool {
        let content = Content(global: global, rooms: rooms)
        guard let data = try? JSONEncoder().encode(content),
              let json = String(data: data, encoding: .utf8)
        else {
            WitlyLog.warning("style controls: failed encoding account data")
            return false
        }
        switch await clientProxy.setWitlyAccountDataEvent(eventType: Self.accountDataEventType, content: json) {
        case .success:
            return true
        case .failure(let error):
            WitlyLog.warning("style controls: failed writing account data: \(error)")
            return false
        }
    }
}
