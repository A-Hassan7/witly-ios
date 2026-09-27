# Witly Module — Agent Guide (iOS)

> **Status:** Active — describes the current `ElementX/Sources/Witly/` module on branch `witly`. **This file does not replace the repo root [`AGENTS.md`](../../../AGENTS.md)** (Element X's own upstream conventions: SwiftLint/SwiftFormat, `AppHooks`, Sourcery/SwiftGen, PR rules, localisation) — that file is untouched and still governs all non-Witly code, and its rules (comment style, member ordering, logging discipline, string localisation) apply to Witly code too unless noted otherwise below.
> **Scope:** `ElementX/Sources/Witly/**` (the additive Witly module) and the small set of Element-core seams that mount it (documented in `PATCHES.md`, root of this repo). Does not attempt to re-document Element X itself.
> **Owner / responsible area:** Witly product frontend (iOS).
> **Last verified date:** 2026-09-27
> **Last verified commit:** `cfe85c49f` (branch `witly`) — **the working tree at verification time has substantial uncommitted changes on top of this commit** (see §8), including a new in-room AI suggestions feature (§3, §7); this document describes the code as it currently exists on disk, not just what's in the last commit.
> **Source documents and paths:** Verified directly by listing and reading every file under `ElementX/Sources/Witly/**`, `PATCHES.md` in full, the root `AGENTS.md`, and cross-referenced with `docs/witly/ios-implementation-plan.md` and `docs/witly/parity-ledger.md` in the parent AGChat repo.
> **Documents this supersedes:** None — this is the first Witly-module-scoped doc. `PATCHES.md` remains authoritative for the exact seam table; this file summarizes and adds module-tree/flow orientation `PATCHES.md` doesn't cover in narrative form.

---

## 1. What this module is

Witly iOS is a fork of [element-hq/element-x-ios](https://github.com/element-hq/element-x-ios), built the same way as the web fork: an **additive, thin-seams layer**. The large majority of Witly code is new files under `ElementX/Sources/Witly/`; Element's own source is touched at a small, documented set of seams (currently 10, see `PATCHES.md`), each preferring the app's own `AppHooks` fork-extension point over a raw core edit where possible.

Remotes: `origin` → `A-Hassan7/witly-ios` · `upstream` → `element-hq/element-x-ios`. Branch `develop` mirrors `upstream/develop`; branch `witly` (branched from stable tag `release/26.09.1`) holds all Witly code — **never commit Witly code to `develop`**.

## 2. Read `PATCHES.md` first

`PATCHES.md` (repo root) is the single source of truth for the exact seam table (10 rows as of this writing — Xcode 27/Swift 6.4 compatibility fixes, the `AppHooks` registration wiring, the onboarding-flow routing seam, the `MXLog.failure`→`.error` crash fix for unverifiable DM recipients, and the two seams mounting the in-room suggestion bar), the `AppHooks` table (which Witly types implement which hook), the "new additive modules" table, and the fork-configuration notes (bundle IDs, entitlements removed, URL scheme). This file adds module-tree and flow-level orientation; treat `PATCHES.md` as authoritative when the two disagree.

## 3. Module tree (`ElementX/Sources/Witly/`)

| Folder | Purpose | Key files |
|---|---|---|
| `Brand/` | `WitlyColorScheme` (theme-flexible palette value type, violet default, ported 1:1 from web's `--witly-*` tokens) + `WitlyCompoundHook` (the `CompoundHookProtocol` implementation that overrides Compound's action/accent/gradient tokens). |
| `Config/` | `WitlyConfig.swift` — backend base URL + Supabase URL/anon key, read from Info.plist with dev fallbacks (`apiBase = https://api.agchat.uk`). |
| `Element/` | `WitlyAppHooks.swift` (`install(into:)` — the one call site seam #1 invokes), `WitlySessionRestorer.swift` (restores an AGChat-provisioned Matrix session into the Rust SDK via public `ClientFactory`/`UserSessionStore` APIs — no core edit), `WitlyCryptoIdentityStore.swift` (persists the local crypto identity/passphrase in Keychain keyed by device ID, so repeated onboarding runs for the same backend-issued device ID reuse the same Olm/crypto material instead of generating fresh keys each time — see §6 for why this matters). |
| `Services/` | `SupabaseAuthService.swift` + `SupabaseOAuthPresenter.swift` (Google OAuth via `ASWebAuthenticationSession`, email/phone OTP), `WitlySession.swift`, `AGChatAPIClient.swift` (typed control-plane client: provisioning, bridge CRUD/status, bridge login-flow steps; custom `Self.jsonDecoder` handles Python's naive-UTC timestamps that lack a timezone suffix), `WitlyProvisioning.swift` (homeserver provisioning poll), `WitlyBridgeConnectController.swift` (`ensureBridgeReady` — deploys/polls a bridge, deletes-and-recreates if found already `ERROR`), `WitlyLog.swift`. |
| `Onboarding/` | `WitlyOnboardingFlowCoordinator.swift` (drives intro → auth → account-setup (if provisioning not yet ready) → connect → session restore; the flow launched by seam #7). Sub-flows: `Intro/` (value-prop + video placeholder, single screen — not a carousel), `Auth/` (Google/email/phone via Supabase), `AccountSetup/` (provisioning-wait screen — rotating emoji + witty line + indeterminate progress bar, shown only while `POST /provision`/`GET /provision/status` is still `PROVISIONING`), `Connect/` (WhatsApp bridge pairing: platform picker → preparing/ready (single merged screen, user stays on the tutorial view until they tap Continue) → phone entry (country-code picker) → pairing code → connected). |
| `Common/` | `WitlyIndeterminateBar.swift` (progress bar driven by `SwiftUI.TimelineView(.animation)` — see §6 for why it isn't a `repeatForever` animation), `WitlySyncingBanner.swift` (neutral "catching up on older messages…" banner, mounted via the `RoomScreen.swift` seam). |
| `Suggestions/` | In-room AI suggestions (P4-equivalent — see §7): `WitlyRoomTimelineWatcher` (read-only timeline observation + Smart-timing burst debounce), `WitlySuggestionsService` (generation orchestration over `AGChatAPIClient.postSuggestions` + `WitlyAIStreamClient`), `WitlyRoomSuggestionsViewModel` (per-room `ObservableObject` state), `WitlySuggestionModels.swift` (shared types), `View/{WitlySuggestionsBarView,WitlySuggestionsBarContainer}.swift` (the compact bar mounted above the composer). `Services/WitlyAIStreamClient.swift` (SSE reader for `GET /ai/stream/{stream_key}`) lives alongside the other networking types. |

## 4. Onboarding flow, in order

```
Intro (single screen, video placeholder)
  → Auth (Google OAuth / email OTP / phone OTP via Supabase)
  → [Account Setup screen, shown only if provisioning is still in flight]
  → Connect (WhatsApp): picker → preparing/ready → phone → pairing code → connected
  → WitlySessionRestorer hands the Matrix session to Element's own session flow
```

`isProvisioningLikelyReady()` in `WitlyOnboardingFlowCoordinator` gates whether the Account Setup screen is shown at all — it is skipped entirely if provisioning finishes fast enough. **Do not reintroduce a `withTaskGroup` race here**: an earlier version raced a 300ms sleep against `await provisioningTask.value` inside `withTaskGroup`, but `withTaskGroup` blocks until ALL child tasks finish (an `await task.value` child has no cancellation checkpoint), so the race silently blocked for the full real provisioning duration instead of returning after 300ms. The current implementation uses a plain `isProvisioningComplete` flag set via `defer` inside the provisioning `Task`, checked after a bare `Task.sleep`.

## 5. Web/iOS parity status (verified against `docs/witly/parity-ledger.md`)

**iOS is materially behind web, but the gap narrowed with the in-room suggestions feature (§7).** As of this writing, iOS has the onboarding flow (intro/auth/connect), the crash/hang fixes below, and a first-cut in-room suggestion bar (single `suggestions/mix` source — no Wit mix/Wildcard/custom Wits fan-out). Web additionally has: the multi-source suggestion engine (per-Wit + Wildcard, `suggestions/`), the tabbed Witly panel (`panel/`), Ask AI (`ask/`), the Wit Library (`wits/`), and the account-settings tab (`account/`) — **none of the panel/Ask AI/Wit Library/account surfaces exist yet in `ElementX/Sources/Witly/`**. `docs/witly/parity-ledger.md`'s iOS/Android columns still read "⬜ not started" across the board (design tokens, terminology, flows, and §5's suggestion-triggering-policy table) — this is stale relative to both the onboarding work and this suggestions work; reconcile the ledger before trusting it for iOS status.

## 6. Fixes worth knowing before touching adjacent code

- **Crypto identity reuse (`WitlyCryptoIdentityStore`):** the backend hands out the *same* Matrix device ID on every re-provision of the same user (sign-out doesn't invalidate it server-side). Generating a fresh local `SessionDirectories()`/crypto identity on every onboarding run desyncs client and server crypto state, producing "Our own device might have been deleted" SDK warnings and an app hang on entering a room. Fixed by persisting the crypto identity + passphrase in Keychain keyed by device ID and reusing it.
- **`RoomScreenViewModel.updateVerificationBadge()` (seam #8):** bridge-puppet users (e.g. WhatsApp ghosts) legitimately have no cross-signing identity — the code already falls back to `.notVerified`, but the old `MXLog.failure(...)` call traps via `assertionFailure` in DEBUG builds outside a debugger. Downgraded to `.error`.
- **`RoomSummaryProvider.buildDiff` — `.remove(index)` bounds check (uncommitted, not yet in `PATCHES.md`):** a genuine, reproducible `EXC_BREAKPOINT` crash was found and fixed in the working tree (`rooms.indices.contains(Int(index))` guard added before the subscript access) but has **not yet been added as a seam row in `PATCHES.md`** — do that in the same commit that lands this fix, so the ledger doesn't drift (see `PATCHES.md` §"Seams" for the row format).
- **`WitlyIndeterminateBar`:** a `repeatForever` SwiftUI animation driven by `@State` is silently interrupted whenever any sibling view in the same hierarchy re-renders (here, a parent's rotating text every 4s) — it stops after one cycle. Fixed by computing the bar's offset as a pure function of wall-clock time via `SwiftUI.TimelineView(.animation)` (must be fully qualified — Element X has its own unrelated `TimelineView` type for the chat timeline).

## 7. In-room AI suggestions (`Suggestions/`)

Seams #9/#10 in `PATCHES.md` mount a compact suggestion bar between the timeline and Element's own composer (`RoomScreen.swift`'s bottom `safeAreaInset`). Split by concern, per the task spec this was built against:

- **Room/timeline observation** — `WitlyRoomTimelineWatcher` consumes the *existing* `TimelineControllerProtocol` already passed to `RoomScreenCoordinator` (the same one `TimelineViewModel` uses) rather than touching the raw Rust SDK or Element's `RoomTimelineItemFactory` — no new coupling to `matrix-rust-sdk` was needed. It tracks new items by `TimelineItemIdentifier` plus a newest-seen-timestamp watermark (so a backward pagination loading *older* history — unseen IDs, but older timestamps — is never misread as new activity) to detect genuinely new inbound vs. own messages, debounces (5s) with a 30s cooldown, and never looks at composer/typing state (typing must never suppress generation — see `docs/witly/product-spec.md` §7.2 / `DRIVE-C3`, and the stale `docs/witly/architecture.md` "suppress-on-typing" line this task corrected).
- **Generation + streaming** — `WitlySuggestionsService` calls `AGChatAPIClient.postSuggestions(feature: "suggestions/mix", ...)` (the backend's zero-config default-mix handler — no Wit selection required, matching `DRIVE-C2`) then reads `WitlyAIStreamClient.stream(streamKey:)`, a minimal `URLSession.bytes(for:)`-based SSE parser for `GET /ai/stream/{stream_key}` (intentionally unauthenticated — the `stream_key` UUID is the capability token, see `docs/project/BACKEND_CONTEXT.md` §7.1).
- **Per-room state** — `WitlyRoomSuggestionsViewModel` (one instance per `RoomScreenCoordinator`, torn down with it) orchestrates both of the above into `idle → generating → streaming → ready` (or `error`), and is the *only* place a generation is cancelled/invalidated (on a new inbound message) or retried (regenerate).
- **UI** — `View/WitlySuggestionsBarView.swift` is a pure, state-in/callbacks-out view (5 `PreviewProvider`/`TestablePreview` states: idle/generating/streaming/ready/error — see §9) with no networking or timeline dependency; `WitlySuggestionsBarContainer` is the thin `@ObservedObject` binding so `RoomScreen.swift`'s own diff stays a single mount line.
- **Composer insertion** — reuses `RoomScreenCoordinator.shareText(_:)` verbatim (already sets mode `.default`, replaces the composer's text, and focuses it) rather than adding a new composer-write seam — tapping a suggestion is functionally identical to the existing share-extension hand-off.
- **Deliberately v1-scoped:** single suggestion source (no wit-mix/Wildcard fan-out — iOS has no wit-mix storage yet, see §5), no Ask AI/Wit Library/panel, no credits UI beyond a generic 402 message, no background/multi-room generation. The ✨ button opens a placeholder "coming soon" toast (`UserIndicatorController`) rather than a real panel — a clean swap point for a future `presentWitlyPanel` action, not a dead end.

## 8. Uncommitted work at time of writing — read before assuming `PATCHES.md`/git history is complete

The working tree (on top of pushed commit `cfe85c49f`) contains uncommitted changes implementing: the room-level "catching up" banner (`RoomScreen.swift` topBanners seam), the full Account Setup screen + flow-coordinator gating fix, the merged Connect preparing/ready screen with tutorial placeholder, the `WitlyIndeterminateBar` `TimelineView` rewrite, `BridgeRemoteState`/`remoteStateCheckedAt` additions to `AGChatAPIClient.swift` (client-side mirror of the backend's bridge health taxonomy — see `docs/project/BACKEND_CONTEXT.md` §4 in the parent repo), the `RoomSummaryProvider.swift` crash fix in §6 above, and the in-room suggestions feature in §7 (seams #9/#10, `Suggestions/`). The `RoomSummaryProvider.swift` fix specifically is **still not reflected in `PATCHES.md`'s seam table** — reconcile that (unrelated to §7) before or alongside committing this work.

## 9. Build / test commands (inherited from root `AGENTS.md`)

```bash
xcodegen                              # regenerate ElementX.xcodeproj from project.yml/target.yml
swift run tools ci unit-tests         # unit tests
```

Most Witly code is still not covered by `{Unit|UI|A11y}Tests` — the exception is `WitlySuggestionsBarView`, whose `PreviewProvider`/`TestablePreview` conformance (idle/generating/streaming/ready/error) is picked up automatically by the Sourcery build phases into `PreviewTests/Sources/GeneratedPreviewTests.swift` (snapshot) and `AccessibilityTests/Sources/GeneratedAccessibilityTests.swift` (`testWitlySuggestionsBarView`) — this is the established Element X pattern for view-level coverage without a dedicated test target; verified by a full `xcodebuild` after adding the previews.
