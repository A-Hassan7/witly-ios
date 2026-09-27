//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// One event parsed from the `GET /ai/stream/{stream_key}` SSE relay. Mirrors the backend's
/// `ai/stream.py` payloads (`{"event": ..., "data": {...}}`) and `ai_worker.py`'s publish calls 1:1.
nonisolated enum WitlyAIStreamEvent: Sendable {
    case suggestion(index: Int, text: String, tone: String?)
    case done(total: Int, tokensUsed: Int)
    /// A structured failure reported by the backend itself (not a transport error).
    case serverError(code: String, message: String)
}

nonisolated struct WitlyAIStreamError: Error, Sendable {
    let message: String
}

/// Reads the AGChat AI Server-Sent-Events relay (`GET /ai/stream/{stream_key}`).
///
/// That endpoint is intentionally **unauthenticated** (the `stream_key` UUID is itself the
/// capability token, since `EventSource`-style clients can't attach an `Authorization` header — see
/// `docs/project/BACKEND_CONTEXT.md` §7.1), so this client sends no bearer token and doesn't go
/// through `AGChatAPIClient.request(_:)`.
///
/// Line format is exactly two header lines per event (`event: <name>` / `data: <json>`) separated by
/// a blank line, per `app/ai/stream.py`'s `subscribe_sse`.
nonisolated struct WitlyAIStreamClient: Sendable {
    private let urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    /// Streams events for `streamKey` until a `done`/`serverError` event, the connection closes, or
    /// the surrounding `Task` is cancelled. Never throws for a *server-reported* failure (that's
    /// delivered as `.serverError`) — the stream only throws on genuine transport failures, so
    /// callers can distinguish "Witly said no" from "the network/request itself failed".
    func stream(streamKey: String) -> AsyncThrowingStream<WitlyAIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = URL(string: "\(WitlyConfig.apiBase)/ai/stream/\(streamKey)")!
                    var request = URLRequest(url: url)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    
                    let (bytes, response) = try await urlSession.bytes(for: request)
                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode)
                    else {
                        continuation.finish(throwing: WitlyAIStreamError(message: "Couldn't open the suggestion stream."))
                        return
                    }
                    
                    var pendingEventName: String?
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        
                        if line.isEmpty {
                            // Blank line: event boundary. Nothing to flush — each event's single
                            // `data:` line is parsed as soon as it's seen (below).
                            continue
                        } else if let name = line.dropPrefix("event:") {
                            pendingEventName = name.trimmingCharacters(in: .whitespaces)
                        } else if let data = line.dropPrefix("data:") {
                            let json = data.trimmingCharacters(in: .whitespaces)
                            if let event = Self.parse(eventName: pendingEventName, jsonString: json) {
                                continuation.yield(event)
                                if case .done = event {
                                    continuation.finish()
                                    return
                                }
                                if case .serverError = event {
                                    continuation.finish()
                                    return
                                }
                            }
                            pendingEventName = nil
                        }
                    }
                    // The connection closed without a done/error event (e.g. the 5-minute relay TTL
                    // elapsed) — treat as a soft completion rather than an error.
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    private static func parse(eventName: String?, jsonString: String) -> WitlyAIStreamEvent? {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        
        switch eventName {
        case "suggestion":
            guard let index = object["index"] as? Int, let text = object["text"] as? String else {
                return nil
            }
            return .suggestion(index: index, text: text, tone: object["tone"] as? String)
        case "done":
            let total = object["total"] as? Int ?? 0
            let tokensUsed = object["tokens_used"] as? Int ?? 0
            return .done(total: total, tokensUsed: tokensUsed)
        case "error":
            let code = object["code"] as? String ?? "unknown_error"
            let message = object["message"] as? String ?? "Something went wrong."
            return .serverError(code: code, message: message)
        default:
            return nil
        }
    }
}

private extension String {
    /// Returns the remainder of the string after `prefix` if present, else `nil`. Used instead of
    /// `hasPrefix`+`dropFirst` at each call site above.
    ///
    /// Marked `nonisolated` because plain extension methods otherwise inherit this module's default
    /// `MainActor` isolation (Xcode 27/Swift 6.4 — see `PATCHES.md` seams #4/#5 for the same issue
    /// elsewhere) — this one's called from `stream(streamKey:)`'s background `Task`.
    nonisolated func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
