# Currency Notch — Build Plan

One phase = one Claude Code session. Start each with `/phase N`.
Each phase: plan → approval → tests first → code → `./scripts/test.sh` green → tick checklist → no commit without approval.

> **Folder-structure phase:** not needed. This is a greenfield repo and the kit already uses the
> workshop structure. If code that doesn't match the structure is added before Phase 1, insert a
> "Phase 0 — Folder structure reorganization" here and do not move code before then.

---

## Phase 1 — Skeleton with one passing test
**Prompt:**
> Create the project skeleton per `docs/ARCHITECTURE.md`: `backend/CurrencyCore` Swift package
> (Swift 6, macOS 26) with one Swift Testing test (`CurrencyCoreTests.versionIsSet`);
> `frontend/CurrencyNotch/project.yml` (XcodeGen, LSUIElement, sandbox + network client
> entitlement, Hardened Runtime, depends on the local package); a minimal app that shows a black
> 200×34 pt rounded panel top-center and a menu bar icon with Quit. Create `scripts/bootstrap.sh`,
> `test.sh`, `build.sh` and `run.sh` (`run.sh` exports `.env` without printing it). Empty
> `Localizable.xcstrings` with he as development language.

**Checklist:**
- [x] `./scripts/bootstrap.sh` checks Xcode 26 + xcodegen and generates the project
- [x] `swift test` in `backend/CurrencyCore` passes (1 test)
- [x] `./scripts/test.sh` runs backend + app tests and exits 0
- [x] `./scripts/build.sh` builds Debug with no warnings in project code
- [x] App launches: no Dock icon, menu bar icon present, black pill visible, Quit works
- [x] `.xcodeproj` is git-ignored; no secrets anywhere

## Phase 2 — Domain models, settings, mock provider
**Prompt:**
> In `CurrencyCore`, implement all SPEC §4 entities as `Codable, Sendable` value types with
> `Decimal` values, the bundled currency catalog (ISO fiat + Coinbase crypto list fixture),
> `SettingsStore` (UserDefaults, schema version, defaults from SPEC §4), `DiskCache`
> (atomic JSON in Application Support), `RateProvider` protocol, `HTTPClient` protocol and
> `MockRateProvider`. Tests first.

**Checklist:**
- [x] Every entity round-trips through JSON in tests
- [x] Defaults match SPEC §4 exactly (base ILS, 8-currency list, 5 s, 120 s, 24h, classic, he)
- [x] Watch list accepts any length ≥ 1, rejects duplicates, keeps order
- [x] Settings migration test: unknown/older schema falls back to defaults safely
- [x] `DiskCache` writes atomically; corrupt file → empty, no crash
- [x] `./scripts/test.sh` green

## Phase 3 — Live rates, fallback, offline, history
**Prompt:**
> Implement `CoinbaseProvider` and `FrankfurterProvider` per `references/rate-apis.md`
> (verify the live endpoints once manually, then record fixtures), `ResponseValidator`,
> `RateHostAllowlist`, `RateService` actor (polling, wake/network triggers, 2-failure fallback,
> exponential backoff, staleness) and `HistoryStore` (24h snapshots → 15-minute buckets, daily series
> for 7d/30d, change %, sparkline points, 35-day pruning). All tests use fixtures — no network.

**Checklist:**
- [x] Inversion math correct: base ILS, USD rate shown as ILS per 1 USD (fixture test)
- [x] Validator rejects: zero, negative, non-finite, >1 MB body, non-allowlisted host, >50% jump (held)
- [x] Primary fails twice → fallback used for fiat; crypto keeps cache; primary recovers → switch back
- [x] Backoff grows to max 15 min and resets on success
- [x] Stale after 3× refresh interval; "no data" state distinct from "stale"
- [x] Change % and sparkline correct for 24h/7d/30d; "collecting" when insufficient
- [x] Cache is loaded on launch before the first fetch
- [x] `./scripts/test.sh` green

## Phase 4 — Floating window, placement, lock
**Prompt:**
> Build `PillPanelController`: borderless non-activating `NSPanel`, desktop level, all Spaces,
> stationary, ignores cycle. First do a 15-minute spike confirming that a desktop-level panel
> receives mouse events on macOS 26; if not, apply the ADR-0004 fallback and update the ADR.
> Implement drag with a 4 pt click threshold, per-display saved origin (missing display → main
> display top-center, clamped on screen), and lock/unlock in the menu bar and right-click menu.

**Checklist:**
- [x] Spike result recorded in ADR-0004
- [x] Placement math unit-tested (clamp, missing display, multiple displays)
- [x] Click-vs-drag threshold unit-tested
- [x] Locked: drag does nothing, click still works
- [x] Manual: visible on every Space; draggable onto a second display; position restored after relaunch

## Phase 5 — Rotation + split-flap
**Prompt:**
> Implement `RotationEngine` in core (interval 3–30 s, pause/resume, list changes mid-rotation)
> and `SplitFlapText` in the app (per-character flip, about 0.4 s, crossfade when Reduce Motion is on).
> Collapsed pill shows `CODE rate symbol` with stale dot.

**Checklist:**
- [x] Engine tests: order, wrap-around, interval change, pause/resume, list edits keep a valid index
- [x] Formatting tests: decimals per currency, base symbol, he/en/ru/zh locales
- [x] Reduce Motion → crossfade (unit-tested flag path)
- [x] Manual: smooth flip, no layout jump between strings of different length

## Phase 6 — Hover expand + click dropdown
**Prompt:**
> Implement hover expand (300 ms in, 200 ms out) showing icon, change % (▲▼ colors) and sparkline,
> and the click dropdown listing all rates (opens upward near the bottom edge; closes on click,
> click outside or Esc). Rotation pauses during both.

**Checklist:**
- [x] View-model tests: change % sign/color, sparkline normalization, empty/collecting states
- [x] Dropdown direction logic unit-tested (top vs bottom of screen)
- [x] Rotation paused while hovered / dropdown open (tested via engine)
- [x] Manual: resize animation smooth; panel frame grows without jumping off-screen

## Phase 7 — Settings UI
**Prompt:**
> Build the menu bar menu (Show/Hide, Lock, Refresh now, Settings…, Quit), mirror it on right-click,
> and the Settings window with Currencies / Display / Alerts / General tabs per SPEC §5.6.
> Changes apply live. Launch at login via `SMAppService`.

**Checklist:**
- [x] Catalog search (code + localized name) unit-tested, fiat + crypto
- [x] Add/remove/reorder/base change persist and reflect in pill immediately
- [x] Intervals clamp to allowed ranges
- [x] Launch-at-login toggle reflects real `SMAppService` status
- [x] Manual: right-click menu identical to menu bar menu

## Phase 8 — Themes and particles
**Prompt:**
> Implement the 5 themes per SPEC §5.7 and `references/themes.md`. Particles via `CAEmitterLayer`
> (Ice snow, Fire sparks + ember flicker, Israel blue/white sparkles + stripe shimmer), clipped to the
> pill/dropdown. Pause on battery/Low Power (setting), when occluded, and with Reduce Motion.
> Frosted Glass uses `glassEffect`. Live preview in settings.

**Checklist:**
- [x] Theme registry test: all 5 IDs resolve; contrast ratio ≥ 4.5:1 computed in tests
- [x] Power-state and occlusion logic unit-tested (pause/resume decisions)
- [x] Manual: each theme looks right collapsed, expanded, dropdown; light + dark wallpaper
- [x] Manual: CPU < 8% with particles, < 2% without (Activity Monitor, 1 min)

## Phase 9 — Rate alerts
**Prompt:**
> Implement `AlertEvaluator` (crossing detection, disarm after firing, re-arm on cross-back,
> base-currency change invalidates alerts with a warning) and `Notifier` (permission on first
> alert, localized message). Alerts tab: add/edit/delete.

**Checklist:**
- [ ] Evaluator tests: above/below, exact-threshold, fire once, re-arm, base change
- [ ] Notification text localized in all 5 languages
- [ ] Manual: real notification appears once when a test threshold is crossed

## Phase 10 — Localization (he RTL, en, es, ru, zh-Hans)
**Prompt:**
> Complete `Localizable.xcstrings` for all strings in 5 languages, add in-app language override,
> verify RTL mirroring (leading/trailing everywhere), LTR isolation for numbers and codes.

**Checklist:**
- [ ] Test: no missing keys in any language
- [ ] Test: number formatting per locale
- [ ] Manual: Hebrew pill, hover, dropdown and settings mirror correctly; no truncation in ru/es

## Phase 11 — Hardening, signing, notarization, release
**Prompt:**
> Run a security review against SPEC §8 and fix the findings. Verify entitlements (sandbox +
> network client only), Hardened Runtime and ATS. Write `scripts/release.sh` (archive → sign with
> `$DEVELOPER_ID_APPLICATION` → notarize with `$NOTARY_KEYCHAIN_PROFILE` → staple → DMG → staple).
> Write README install notes for friends. Ask before running the release.

**Checklist:**
- [ ] `grep` shows no secrets, no `http://`, no ATS exceptions, no full-response logging in Release
- [ ] `codesign --verify --deep --strict` and `spctl -a -vv` pass on the built app
- [ ] Notarization succeeds; DMG stapled
- [ ] Manual: DMG opens on a second Mac with no Gatekeeper warning
- [ ] SPEC §6 Definition of Done: every item ticked
