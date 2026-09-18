//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Thin `[Witly]`-prefixed wrapper over `MXLog` so Witly log lines are easy to filter and Witly code
/// doesn't depend on the logging backend directly.
nonisolated enum WitlyLog {
    static func info(_ message: String) {
        MXLog.info("[Witly] \(message)")
    }
    
    static func warning(_ message: String) {
        MXLog.warning("[Witly] \(message)")
    }
    
    static func error(_ message: String) {
        MXLog.error("[Witly] \(message)")
    }
}
