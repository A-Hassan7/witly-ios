//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Thin `[Witly]`-prefixed wrapper over `MXLog` so Witly log lines are easy to filter and Witly code
/// doesn't depend on the logging backend directly.
///
/// To see `.verbose` lines: run the app, tap the version number in Settings 7 times to reveal
/// "Developer options", then set Log level to "Trace" (requires an app relaunch) — `.info` and above
/// are visible without changing anything. Either way, filter Xcode's debug console (or macOS
/// Console.app, if you'd rather not use Xcode at all) for "[Witly]" to see only these lines.
nonisolated enum WitlyLog {
    static func verbose(_ message: String) {
        MXLog.verbose("[Witly] \(message)")
    }
    
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
