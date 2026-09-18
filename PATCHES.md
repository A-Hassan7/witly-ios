# Witly fork — PATCHES

This is a **fork of [element-hq/element-x-ios](https://github.com/element-hq/element-x-ios)**. Witly is built
as an **additive, thin-seams layer** on top of Element X (see `docs/witly/ios-implementation-plan.md` in the
parent AGChat repo).

**The rule:** the large majority of Witly lives in **new files** under `ElementX/Sources/Witly/`. Element's own
source is touched **only** at the small, documented set of seams listed below — each just enough to mount a
Witly surface, and each preferring the app's official extension point (`AppHooks`) over a raw core edit. This
file is the single source of truth for those seams, so they can be **re-applied after every upstream merge**.

## Branch model

| Branch | Role |
|---|---|
| `develop` | Mirror of `upstream/develop` (element-hq/element-x-ios) at fork time. **Never** commit Witly code here. |
| `witly` | Our working branch, branched from the stable tag `release/26.09.1`. All Witly code + the seams below live here. |

Remotes: `origin` → `A-Hassan7/witly-ios` · `upstream` → `element-hq/element-x-ios`.

## Upstream-merge workflow

```bash
# from client/witly-ios
git fetch upstream
git checkout develop && git merge --ff-only upstream/develop   # keep mirror in sync (optional)
git checkout witly && git merge upstream/develop               # or merge a newer upstream release tag
# re-check each seam below still applies (esp. AppHooks signatures); regenerate with `xcodegen`; build
```

## AppHooks (the preferred attach point — no core edit)

`ElementX/Sources/AppHooks/AppHooks.swift` is Element's own fork-extension seam: a set of `@AppHook`
properties, each swappable via a generated `register<Name>(_:)` method, called from `AppHooks().setUp()` in
`AppCoordinator.init`. Witly registers its own hook implementations there — **this is not a "seam" in the
table below because it requires no core edit**, just a call into an API Element already ships for this exact
purpose.

| Hook | Witly implementation | Purpose |
|---|---|---|
| `compoundHook` | `WitlyCompoundHook` | Overrides Compound accent/action/gradient colour tokens with the Witly brand (violet; theme-flexible scheme indirection). |
| `appSettingsHook` | `WitlyAppSettingsHook` | `AppSettings.override(...)`: brand chrome off, Witly URLs, backend hosts. |
| `clientFactoryHook` | `WitlyClientFactoryHook` | Builds/restores the Matrix `Session` from AGChat-provisioned credentials. |

## Seams (Element X core files we modify)

> Keep this table exhaustive. Each row: the file, what we changed, and why. Prefer `AppHooks` over editing
> core; only add a row here when no hook reaches.

| # | Element file | Change | Why | Status |
|---|---|---|---|---|
| 1 | `ElementX/Sources/Application/AppCoordinator.swift` (`init`) | Register `WitlyAppHooks`' hook implementations via the generated `register<Name>(_:)` calls, immediately after `appHooks.setUp()`. | `AppHooks` is designed for exactly this, but *which* concrete hooks are installed still has to be wired from somewhere in the app's startup — this one call site is that wiring. Purely additive; reverting it (and removing `Witly/`) restores vanilla Element X hooks (all `Default*` no-ops). | active |
| 2 | `ElementX/Sources/Application/AppCoordinator.swift` (`init`) | Wrap the `appHooks.compoundHook.override(colors:uiColors:)` call in `MainActor.assumeIsolated { }`. | Under Xcode 27/Swift 6.4, `init` is no longer inferred as `@MainActor` even though the target sets `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`, so the MainActor-isolated `Color.compound`/`UIColor.compound` (Compound package uses `.defaultIsolation(MainActor.self)`) can't be referenced directly. `init` genuinely only ever runs on the main thread at app launch, so this is a safe assertion, not a behaviour change. Standard Swift API, compiles fine under Xcode 26.5 too. | active |
| 3 | `compound-ios/Sources/Compound/Colors/CompoundUIColors.swift` (`UIColor.compound`, `CompoundUIColors`) | Added `nonisolated` to the `static let compound` accessor, and `@unchecked Sendable` to the `CompoundUIColors` class. | `CompoundUIColors` itself is already declared `nonisolated class` upstream (explicitly for attributed-string/background-thread use per its own doc comment), but the exposing `UIColor.compound` static property wasn't, so it fell back to the package's `.defaultIsolation(MainActor.self)`. Under Xcode 27/Swift 6.4 this now surfaces as a hard error (e.g. `AttributedStringBuilder`, used by the NSE, reading `UIColor.compound._bgCodeBlock` off the main thread). Making the property `nonisolated` alone then requires the type to be `Sendable`; `@unchecked` is safe since `overrides` is only ever written once at startup before concurrent reads begin (same pattern already used throughout the codebase, e.g. Sourcery's generated mocks). Matches the upstream code's own stated intent; standard Swift syntax, compiles fine under Xcode 26.5 too. | active |
| 4 | `ElementX/Sources/Other/VoiceMessage/EstimatedWaveformView.swift` (`WaveformShape.path(in:)`) and `ElementX/Sources/Other/SwiftUI/Views/RoundedCornerShape.swift` (`RoundedCornerShape.path(in:)`) | Marked both `path(in:)` implementations `nonisolated`. | `Shape.path(in:)` is a nonisolated SwiftUI protocol requirement; under Xcode 27/Swift 6.4 the module's default `MainActor` isolation makes the conformance "cross into main actor-isolated code", which is now a hard error (`#ConformanceIsolation`) rather than a warning. Both methods are pure geometry computations with no MainActor-only API use, so `nonisolated` is correct, not just a workaround — matches the compiler's own suggested fix. Standard Swift syntax, compiles fine under Xcode 26.5 too. | active |
| 5 | `ElementX/Sources/Other/NetworkMonitor/NetworkMonitorProtocol.swift` (`NetworkMonitorReachability`, `HomeserverReachability`) | Marked both enums `nonisolated`. | Their synthesized `Equatable` conformances were inheriting the module's default `MainActor` isolation, but `MediaProvider`'s retry loop (`for await reachability in ...`) compares them (`reachability == .reachable`) from an off-main-actor (`@concurrent`) context. Both are plain, threadsafe value-type network-state enums with no reason to be MainActor-bound. Standard Swift syntax, compiles fine under Xcode 26.5 too. | active |
| 6 | Miscellaneous warning cleanup (non-functional): `ElementX/Sources/Other/HTMLParsing/ElementXAttributeScope.swift` (added explicit `import SwiftUI`/`import UIKit` — first tried `import SwiftUICore` directly, reverted, since it's an implementation-detail module Swift refuses to import directly), `ElementX/Sources/Services/Client/ClientFactory.swift` (`var client` → `let client`), several `Task { }`/`DispatchQueue...async { }` sites given explicit `[self]` capture where an inner closure already captured `[weak self]` (`AppCoordinator.swift`, `SpaceScreenViewModel.swift`, `RoomMembersFlowCoordinator.swift`, `HomeScreenViewModel.swift`, `NotificationSettingsEditScreenViewModel.swift`, `MessageComposerTextField.swift`, `KnockRequestsListScreenViewModel.swift`), and several fire-and-forget `Task { }` sites given an explicit `_ = ` discard (`WindowManager.swift`, `UserSessionFlowCoordinator.swift`, `UserIndicatorController.swift`, `PollFormScreenViewModel.swift`, `SessionVerificationControllerProxyMock.swift`, `Tools/Scripts/Templates/SimpleScreenExample/ElementX/TemplateScreenViewModel.swift`). | All warnings under Xcode 27/Swift 6.4 (isolated-conformances, ambiguous capture semantics, unused throwing-task results); no behaviour change, all standard Swift syntax valid under Xcode 26.5 too. | active |
| 7 | `ElementX/Sources/Application/AppCoordinator.swift` (`startAuthentication()`, class conformance, `witlyOnboardingFlowCoordinator` property, `WitlyOnboardingFlowCoordinatorDelegate` conformance) | Route the signed-out state to `WitlyOnboardingFlowCoordinator` (intro → auth → connect) instead of Element's own `AuthenticationFlowCoordinator`, using the same `didLoginWithSession` handoff pattern. | No `AppHook` reaches "which auth flow to launch" — this is iP1's core seam. Fully additive/reversible: restoring the original `startAuthentication()` body (see git history prior to this seam) and dropping the new delegate conformance reverts to vanilla Element auth. | active |
| 8 | `ElementX/Sources/Screens/RoomScreen/RoomScreenViewModel.swift` (`updateVerificationBadge()`) | Changed `MXLog.failure(...)` to `MXLog.error(...)` when a DM recipient has no resolvable cross-signing identity. | `MXLog.failure` calls `assertionFailure` in DEBUG, which traps (SIGTRAP) and crashes the app outside a debugger. Bridge puppet users (e.g. WhatsApp ghosts) legitimately have no cross-signing identity — an expected, recoverable case (the code already falls back to `.notVerified` either way), not a real programming error worth crashing over. | active |

**Reverted (do not reapply):** `ElementX/Sources/Other/Extensions/Alert.swift`'s `AlertInfo<T: Hashable>` was briefly changed to `T: Hashable & Sendable` to silence an isolated-conformance *warning*, but several real alert-type enums used as `T` (e.g. `LocationSharingViewAlert`, `SecureBackupLogoutConfirmationScreenAlertType`, `ServerSelectionScreenErrorType`, `TimelineAlertInfoType`, `UserProfileScreenAlertType`) have MainActor-isolated `Hashable` conformances that don't satisfy `Sendable`, turning the warning into ~69 hard errors elsewhere. Reverted back to `T: Hashable` — that warning is left as-is.


<!--
Template for a new seam:
| 2 | ElementX/Sources/Screens/RoomScreen/View/RoomScreen.swift | Mount WitlySuggestionBar in the safeAreaInset VStack, above `composer` | No AppHook reaches the room-screen composer footer | active |
-->

## New (additive) Witly modules

Additive code that does **not** count as a seam (no upstream conflict risk). Recorded for orientation.
All live under `ElementX/Sources/Witly/` and are picked up automatically by `xcodegen` (the `ElementX`
target's `sources` already includes the whole `Sources` folder recursively).

| Area | Location (in fork) | Notes |
|---|---|---|
| AppHooks install point | `ElementX/Sources/Witly/Element/WitlyAppHooks.swift` | `install(into:)` — the only file seam #1 calls into. |
| Brand palette | `ElementX/Sources/Witly/Brand/WitlyColorScheme.swift` | `WitlyColorScheme` value type (theme-flexible) + `WitlyBrand.colorScheme` (violet default), ported 1:1 from the web `--witly-*` tokens. |
| Compound theming | `ElementX/Sources/Witly/Brand/WitlyCompoundHook.swift` | `CompoundHookProtocol` impl; overrides Compound's action/accent colour + gradient tokens with the brand palette. |
| Config | `ElementX/Sources/Witly/Config/WitlyConfig.swift` | Backend + Supabase base URL/key, from Info.plist w/ dev fallbacks. |
| Networking | `ElementX/Sources/Witly/Services/{WitlySession,SupabaseAuthService,SupabaseOAuthPresenter,AGChatAPIClient,WitlyProvisioning,WitlyBridgeConnectController,WitlyLog}.swift` | Supabase auth (Google OAuth via `ASWebAuthenticationSession` + email/phone OTP), AGChat control-plane client (provisioning + bridge/login endpoints), homeserver provisioning poll, WhatsApp bridge deploy/login helper. |
| Session restore | `ElementX/Sources/Witly/Element/{WitlySessionRestorer,WitlyCryptoIdentityStore}.swift` | Restores an AGChat-provisioned Matrix session into the Rust SDK via public `ClientFactory`/`UserSessionStore` APIs (no core edit); persists the local crypto identity per device ID so repeated onboarding runs reuse it instead of generating a fresh one each time (see seam #7's sibling bug fix history). |
| Onboarding UI | `ElementX/Sources/Witly/Onboarding/` (`WitlyOnboardingFlowCoordinator` + `Intro/`, `Auth/`, `Connect/`) | Intro (value-prop + video placeholder) → auth (Google/email/phone) → connect (WhatsApp bridge pairing state machine w/ country-code phone picker). Launched by seam #7. |

## Fork configuration (not a seam — `app.yml`/`target.yml` config, no source edits)

- `app.yml`: rebranded (`APP_DISPLAY_NAME`/`PRODUCTION_APP_NAME` = Witly, `APP_GROUP_IDENTIFIER` =
  `group.uk.agchat.witly`, `BASE_BUNDLE_IDENTIFIER` = `uk.agchat.witly`, `DEVELOPMENT_TEAM` blank — no
  Apple Developer account for this phase, Simulator builds use "Sign to Run Locally").
- `ElementX/SupportingFiles/target.yml` entitlements: removed `aps-environment` (Push Notifications),
  `com.apple.developer.associated-domains` (Element's own applink/webcredentials domains),
  `com.apple.developer.usernotifications.communication` (Communication Notifications). All three
  require a paid-account provisioning profile even for Simulator builds, and none are in scope for
  Stage 1-4 (push is explicitly deferred — see `docs/witly/ios-implementation-plan.md` §13). App Groups
  + Keychain Sharing are kept (needed for app/extension data sharing, no paid account required). Re-add
  push once Witly has its own push design; re-add associated domains once Witly has its own domain for
  an OAuth/deep-link callback.
- `app.yml`: Element Classic migration identifiers (`CLASSIC_APP_GROUP_IDENTIFIER`,
  `CLASSIC_APP_KEYCHAIN_SERVICE_IDENTIFIER`, `CLASSIC_APP_KEYCHAIN_ACCESS_GROUP_IDENTIFIER`,
  `CLASSIC_APP_DEEP_LINK_URL`) were re-pointed from Element's own `group.im.vector`/`im.vector.app.*`
  values to unique `uk.agchat.witly.*` ones. Kept the Classic-migration *feature code* as-is (not removed —
  it's a large surface area); this migration flow is effectively a no-op for Witly (no real "Classic app"
  counterpart), the actual risk being avoided is an App Group/keychain identifier collision with Element's
  real app during provisioning.
- `NSE/SupportingFiles/target.yml` entitlements: removed `com.apple.developer.usernotifications.filtering`
  — an Apple-managed entitlement that requires explicit approval and isn't available for local/initial
  forks. Request it from Apple later if the fork needs to suppress notifications after processing them.
- `ElementX/SupportingFiles/target.yml`/`Info.plist` `CFBundleURLSchemes`: added `"witly"` alongside the
  existing `$(BASE_BUNDLE_IDENTIFIER)`/`"matrix"` schemes, so Supabase's Google OAuth can redirect to
  `witly://auth-callback` (handled by `SupabaseOAuthPresenter` via `ASWebAuthenticationSession`). Requires
  `witly://auth-callback` to be on Supabase's Redirect URLs allow-list (Dashboard → Authentication → URL
  Configuration) — without it Supabase falls back to its configured Site URL instead of the app.
- **Known discrepancy to resolve before the next `xcodegen` regen:** the checked-in
  `ElementX.xcodeproj` currently has `DEVELOPMENT_TEAM` set to a real Apple team ID (set via Xcode's
  Signing & Capabilities UI, for on-device/TestFlight signing), but `app.yml`'s `DEVELOPMENT_TEAM` is
  still blank. Since `app.yml` is the xcodegen source of truth, running `xcodegen` again will silently
  wipe the team back to blank. Fill in `app.yml`'s `DEVELOPMENT_TEAM` with the real value once you're
  ready to commit to a specific team for this fork.

## Module API dependency notes

Witly attaches primarily via `AppHooks` (Element's own fork-extension API, used internally for their
commercial/enterprise builds — actively maintained, not a deprecated path). Where a hook doesn't reach
(confirmed case-by-case, not assumed), a minimal core seam is added above instead.
