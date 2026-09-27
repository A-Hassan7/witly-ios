//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

/// The single, additive install point for all Witly `AppHooks` implementations.
///
/// Called once from `AppCoordinator.init`, immediately after `appHooks.setUp()` and before
/// Element's own `appHooks.compoundHook.override(...)` call runs (PATCHES.md seam #1). Adding a
/// new hook is a one-line addition here, never a change to `AppHooks.swift` itself.
///
/// This runs before `Target.mainApp.configure(...)` sets up `MXLog`'s root tracing span, so
/// `WitlyLog` calls made from here (or anything else this early) are silently dropped — see the
/// app-launch log in `AppCoordinator.init` instead.
enum WitlyAppHooks {
    static func install(into appHooks: AppHooks) {
        appHooks.registerCompoundHook(WitlyCompoundHook())
        // appSettingsHook / clientFactoryHook land in iP1 (session handoff + rebrand config).
    }
}
