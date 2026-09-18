//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

/// The single, additive install point for all Witly `AppHooks` implementations.
///
/// Called once from `AppCoordinator.init`, immediately after `appHooks.setUp()` and before
/// Element's own `appHooks.compoundHook.override(...)` call runs (PATCHES.md seam #1). Adding a
/// new hook is a one-line addition here, never a change to `AppHooks.swift` itself.
enum WitlyAppHooks {
    static func install(into appHooks: AppHooks) {
        appHooks.registerCompoundHook(WitlyCompoundHook())
        // appSettingsHook / clientFactoryHook land in iP1 (session handoff + rebrand config).
    }
}
