# Currency Notch — Project Brief Prompt

> The workshop template filled in for this project, in English.
> Part A is the brief. Part B is the first message to paste into Claude Code.

---

## Part A — Project brief

**Goal:** A native macOS floating, notch-sized pill that rotates through the user's chosen exchange rates (fiat + crypto) every few seconds, so live rates are always one glance away on the desktop.

**Users:** The owner (a single macOS 26 user in Israel) and a few friends who receive a signed, notarized .dmg. No accounts, no server.

**Entities:**
Currency (code, name, kind[fiat|crypto], symbol, flagOrIcon, decimals) ·
RateQuote (quoteCode, baseCode, value[Decimal], fetchedAt, source) ·
HistoryPoint (quoteCode, baseCode, timestamp, value) ·
WatchList (baseCode, orderedCodes[]) ·
RateAlert (id, quoteCode, baseCode, direction[above|below], threshold, isArmed, lastTriggeredAt) ·
WidgetPlacement (screenID, originX, originY, isLocked) ·
ThemeID (ice | fire | israel | classicNotch | frostedGlass) ·
AppSettings (rotationInterval, refreshInterval, changeRange[24h|7d|30d], themeID, language, launchAtLogin, pauseEffectsOnBattery)

**The project is done when:**
- The pill launches at desktop level, is roughly notch-sized, shows on every Space and every connected display, and can be dragged anywhere.
- Position is remembered across restarts (per display), and a lock/unlock toggle prevents accidental dragging.
- The pill rotates through any number of chosen currencies at a configurable interval (default 5 s, range 3–30 s), with a split-flap "airport board" animation.
- Hovering expands the pill to show flag/icon, change % (green ▲ / red ▼) and a mini sparkline for the selected range (24h / 7d / 30d).
- Clicking drops down a list of all chosen rates (Dynamic-Island style); clicking again or clicking away closes it; drag never triggers click.
- Live rates for fiat + crypto load from free, key-less HTTPS sources, refresh every few minutes, and fall back to a second source on failure.
- When offline or when data is stale, the pill shows a stale indicator and "last updated" time instead of failing silently.
- Base currency and the watch list (search, add, remove, reorder) are editable from a menu bar icon and from right-clicking the pill.
- All 5 themes work: Ice, Fire, Israel (blue/white) with full particle effects; Classic Black Notch; Frosted Glass (Liquid Glass). Effects pause on battery / Low Power Mode (toggleable) and respect Reduce Motion.
- Rate alerts (above/below threshold) send a macOS notification once per crossing and re-arm when the rate crosses back.
- Launch at login works and can be toggled.
- The UI is fully localized in Hebrew (default, RTL), English, Spanish, Russian and Chinese (Simplified).
- `./scripts/test.sh` passes; a signed + notarized .dmg is produced by `./scripts/release.sh` and opens on a second Mac without Gatekeeper warnings.

**What we build, by phase:**
1. Skeleton: XcodeGen project + `CurrencyCore` Swift package + one passing test + scripts + empty pill and menu bar icon.
2. Domain models, settings persistence, mock provider for tests.
3. Live rate providers (Coinbase primary, Frankfurter fallback), polling, cache, offline/stale state, history store.
4. Floating window: desktop level, all Spaces, multi-display, drag, remember position, lock/unlock.
5. Rotation engine + split-flap animation.
6. Hover expand (flag, change %, sparkline) + click dropdown of all rates.
7. Settings UI (menu bar + right-click): watch list, base, intervals, range, theme, language, launch at login, lock.
8. Themes: 5 themes, particle effects, battery and Reduce Motion handling.
9. Rate alerts with notifications.
10. Localization: he (RTL), en, es, ru, zh-Hans.
11. Security hardening, signing, notarization, DMG release.

**Out of scope:** Apple WidgetKit widgets · Docker · any backend server or database · Mac App Store · iOS/iPadOS/Windows/Linux · user accounts · currency converter or trading · paid or key-required APIs · analytics/telemetry · CI pipelines.

**Security focus:** HTTPS-only to an allowlist of rate hosts (ATS with no exceptions) · treat every API response as untrusted (strict decoding, size limits, reject non-finite/zero/negative/absurd values, never crash) · no secrets in the repo or the app binary; signing/notary credentials only in env vars / Keychain profiles · App Sandbox (network client only) + Hardened Runtime + notarization · no telemetry · no third-party dependencies without an ADR.

**Bonus — only after the core is ready:** None. Every feature above is core.

**Architecture:** Native app only — no DB, no server. `backend/` = `CurrencyCore` Swift package (pure logic: models, providers, rotation, history, alerts; no UI). `frontend/` = SwiftUI + AppKit macOS app that depends on it. Persistence = UserDefaults (settings) + JSON files in Application Support (cache, history).
**Stack:** Swift 6, SwiftUI + AppKit (NSPanel), Core Animation (CAEmitterLayer) for particles, Swift Testing, XcodeGen, macOS 26 Tahoe deployment target.

**Organization constraints (with project exceptions):**
- ~~Mock data only~~ → **Exception:** live data from day one; mocks only inside tests. (ADR-0002)
- Secrets only in environment variables → kept (`.env`, never committed, never read by Claude).
- ~~Everything runs in Docker~~ → **Exception:** native macOS app; Docker cannot host it. (ADR-0001)
- Private GitHub repo → kept (no CI; PR + issue templates only).
- Hebrew UI (RTL), code in English → kept; plus en/es/ru/zh-Hans.

---

## Part B — First message for Claude Code

```
Read CLAUDE.md, docs/SPEC.md, docs/ARCHITECTURE.md and docs/build-plan.md.
Do not write code yet. Summarize in 10 bullets what you understood, list any
contradictions or missing decisions you see, then wait. When I approve, run
/phase 1.
```
