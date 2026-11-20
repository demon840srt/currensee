# Currency Notch — Specification

Version 1.0 · 2026-11-20 · Status: approved for build

## 1. Goal
A native macOS floating, notch-sized pill that rotates through the user's chosen exchange rates
(fiat + crypto) every few seconds, so live rates are always one glance away on the desktop.

## 2. Users
- **Owner:** one macOS 26 Tahoe user in Israel (Hebrew UI by default).
- **Friends:** receive a signed, notarized `.dmg`. No accounts, no server, no shared data.

## 3. Constraints and exceptions
| Workshop rule | Status | Note |
|---|---|---|
| Mock data only | **Exception** | Live data from day one; mocks only in tests (ADR-0002) |
| Secrets only in env vars | Kept | Only signing/notary credentials exist; app needs no keys |
| Everything in Docker | **Exception** | Native macOS app cannot run in Docker (ADR-0001) |
| Private GitHub repo | Kept | No CI; PR + issue templates only |
| Hebrew UI (RTL), code in English | Kept | Plus en, es, ru, zh-Hans |
| db + backend + frontend | Adapted | No DB/server; `backend/` = core Swift package (ADR-0003) |

## 4. Entities
| Entity | Fields | Stored in |
|---|---|---|
| Currency | code, name, kind (fiat/crypto), symbol, flagOrIcon, decimals | Bundled catalog + provider list |
| RateQuote | quoteCode, baseCode, value (Decimal), fetchedAt, source | Memory + `cache.json` |
| HistoryPoint | quoteCode, baseCode, timestamp, value | `history.json` (Application Support) |
| WatchList | baseCode, orderedCodes[] (any length ≥ 1) | UserDefaults |
| RateAlert | id, quoteCode, baseCode, direction (above/below), threshold, isArmed, lastTriggeredAt | UserDefaults |
| WidgetPlacement | screenID, originX, originY (lock is global, ADR-0015) | UserDefaults (one per screen) + last-used screen ID |
| ThemeID | ice, fire, israel, classicNotch, frostedGlass | — |
| AppSettings | rotationInterval (s), refreshInterval (s), changeRange (24h/7d/30d), themeID, language, launchAtLogin, pauseEffectsOnBattery, isPositionLocked | UserDefaults |

**Defaults:** base `ILS`; watch list `USD, EUR, GBP, JPY, CHF, CNY, BTC, ETH`; rotation 5 s;
refresh 120 s; range 24h; theme Classic Black Notch; language Hebrew; launch at login on;
pause effects on battery on. Decimals: 4 for fiat, 2 for JPY, 5 for crypto (ADR-0009).

## 5. Functional requirements

### 5.1 Window and placement
- F1. The pill is a borderless, non-activating `NSPanel`, about notch size (collapsed ≈ 200×34 pt).
- F2. It sits at **desktop level** (under normal app windows) and joins all Spaces (`canJoinAllSpaces`, `stationary`, `ignoresCycle`). No Dock icon (`LSUIElement`).
- F3. It can be dragged to any position on any connected display.
- F4. Its position is saved per display and restored after relaunch. If that display is gone, it moves to the main display, top-center.
- F5. A **Lock position** toggle (menu bar, right-click, settings) disables dragging. When locked, a drag does nothing and a click still works.
- F6. Click vs drag: movement under 4 pt between mouse down and up counts as a click; anything more counts as a drag.

### 5.2 Rotation
- F7. Rotates through **all** watch-list currencies in order, one at a time, every `rotationInterval` (default 5 s, range 3–30 s).
- F8. The change uses a **split-flap (airport board)** animation, character by character, about 0.4 s long.
- F9. Rotation pauses while the pill is hovered or the dropdown is open, and resumes afterwards.
- F10. Collapsed content: currency code + rate in base currency (e.g. `USD 3.7012 ₪`), with a stale dot when applicable.

### 5.3 Hover expand
- F11. After hovering 300 ms, the pill expands (≈ 280×64 pt) to show the flag (fiat) or coin icon (crypto), code, rate, change % for the selected range (green ▲ / red ▼ / grey =), and a mini sparkline.
- F12. Leaving the pill collapses it after 200 ms.

### 5.4 Click dropdown
- F13. A click opens a Dynamic-Island-style dropdown below the pill listing **all** watch-list rates (icon, code, rate, change %).
- F14. Click on the pill again, click outside, or press Esc to close it.
- F15. Near the bottom edge of a screen, the dropdown opens upward.

### 5.5 Rates and data
- F16. **Primary source:** Coinbase `GET /v2/exchange-rates?currency=<BASE>` (no key, fiat + crypto). The value shown is `1 / rates[code]`, meaning the price of one unit of the quote currency in base currency.
- F17. **Fallback source:** Frankfurter v2 (no key, fiat only), used when the primary source fails twice in a row. Crypto stays on its last cached value until the primary source recovers.
- F18. Refresh every `refreshInterval` (default 120 s, min 60 s), plus on wake from sleep and when the network returns. Exponential backoff on errors (max 15 min).
- F19. The last good quotes are cached to disk and shown on launch before the first fetch.
- F20. **Stale state:** a quote older than 3× the refresh interval, or no network → show a stale dot and "Updated <relative time>" in hover and dropdown. With no data at all, show "—" and "Offline".
- F21. **History for sparkline and change %:**
  - 24h: local snapshots recorded at every refresh (downsampled to 15-minute buckets).
  - 7d / 30d: daily series. Fiat comes from the Frankfurter time series; crypto from the Coinbase historic spot price (`/v2/prices/<CODE>-<BASE>/spot?date=`). Cached and refreshed once a day.
  - Until enough data exists, the sparkline shows "collecting…" and change % is hidden.
  - History is pruned to 35 days. Intraday snapshots are kept 48 h; the 24h series is seeded from the latest daily value until snapshots cover it (ADR-0014).

### 5.6 Settings (menu bar icon + right-click on the pill)
- F22. A menu bar icon menu offers: Show/Hide pill, Lock/Unlock position, Refresh now, Settings…, Quit. Right-clicking the pill shows the same menu.
- F23. Settings window tabs:
  - **Currencies:** search the full catalog (fiat + crypto), add, remove, drag to reorder, pick the base currency.
  - **Display:** rotation interval, change range, theme picker with live preview.
  - **Alerts:** list, add, edit and delete alerts.
  - **General:** language, launch at login, pause effects on battery, refresh interval.
- F24. Every change applies instantly, with no Save button.

### 5.7 Themes
| Theme | Look | Effect |
|---|---|---|
| Ice | Ice blue → white gradient, frosted rim | Falling snowflakes, frost shimmer on the rim |
| Fire | Deep red → orange → amber | Rising sparks, flickering ember glow |
| Israel | White body, flag-blue `#0038B8` stripes top and bottom, subtle Star of David watermark | Drifting blue and white sparkles, waving shimmer across the stripes |
| Classic Black Notch | Pure `#000000`, merges with the MacBook notch | None |
| Frosted Glass | macOS 26 Liquid Glass (`glassEffect`) | None |
- F25. Particles use `CAEmitterLayer` and stay clipped to the pill (and the dropdown when it's open).
- F26. Particles pause when on battery or in Low Power Mode (if the setting is on) and when the pill is fully covered. With Reduce Motion on, particles are off and the split-flap becomes a crossfade.
- F27. Text contrast is at least WCAG AA 4.5:1 in every theme.

### 5.8 Alerts
- F28. An alert is defined by a currency, a direction (above/below) and a threshold, in the current base currency.
- F29. When a refresh crosses the threshold, the app sends one local notification ("USD rose above 3.80 ₪") and disarms the alert. The alert re-arms when the rate crosses back. Notification permission is requested on the first alert created.

### 5.9 Localization
- F30. Languages: Hebrew (default, RTL), English, Spanish, Russian, Chinese (Simplified). Follows the system language unless overridden in settings.
- F31. In RTL the layout mirrors. Numbers and currency codes stay LTR inside RTL text. Numbers are formatted with the selected locale.

### 5.10 System
- F32. Launch at login via `SMAppService.mainApp`, toggleable.
- F33. Memory under 80 MB and idle CPU under 2% with particles off (target under 8% with particles on).

## 6. Definition of done
- [ ] The pill launches at desktop level, is roughly notch-sized, shows on every Space and display, and can be dragged anywhere.
- [ ] Position is remembered per display across restarts; lock/unlock prevents accidental dragging.
- [ ] Rotates through any number of currencies at a configurable interval (default 5 s, 3–30 s) with split-flap animation.
- [ ] Hover expands to show flag/icon, change % and sparkline for 24h/7d/30d.
- [ ] Click opens a dropdown of all rates; click again, click away or Esc closes it; drag never triggers click.
- [ ] Live fiat + crypto rates from key-less HTTPS sources, refreshing every few minutes, with fallback.
- [ ] Offline/stale state is shown with "last updated" time.
- [ ] Base currency and watch list (search, add, remove, reorder) editable from the menu bar and right-click.
- [ ] All 5 themes work; particles on Ice/Fire/Israel; battery pause and Reduce Motion respected.
- [ ] Rate alerts notify once per crossing and re-arm.
- [ ] Launch at login works and is toggleable.
- [ ] UI fully localized: he (RTL, default), en, es, ru, zh-Hans.
- [ ] `./scripts/test.sh` passes; `./scripts/release.sh` produces a signed, notarized DMG that opens on a second Mac without warnings.

## 7. Out of scope
WidgetKit widget · Docker · server or database · Mac App Store · iOS/iPadOS/Windows/Linux ·
user accounts · converter/trading · paid or keyed APIs · analytics/telemetry · CI pipelines.

## 8. Security focus
- HTTPS only; hosts allowlisted (`api.coinbase.com`, `api.frankfurter.dev`); ATS with no exceptions.
- Every response is untrusted: strict `Codable` decoding, 1 MB size cap, 10 s timeout. Reject zero, negative, non-finite or absurd values (more than 50% jump from the last good value is held until confirmed by the next refresh).
- Parsing failures never crash and never overwrite good cached data.
- No secrets in the repo, `project.yml`, Info.plist or binary. Signing/notary credentials come only from env vars / Keychain profile.
- App Sandbox with `network.client` only; Hardened Runtime; Developer ID signing; notarized and stapled.
- No telemetry. Release logs contain no response bodies.
- No third-party packages without an ADR.

## 9. Bonus
None — every feature is core (owner decision, 2026-11-20).

## 10. Decision log
| # | Date | Decision | ADR |
|---|---|---|---|
| 1 | 2026-11-20 | Native Swift app only; Docker rule waived | 0001 |
| 2 | 2026-11-20 | Live data from day one (Coinbase + Frankfurter, key-less); mocks only in tests | 0002 |
| 3 | 2026-11-20 | `backend/` = `CurrencyCore` Swift package, `frontend/` = macOS app; no DB | 0003 |
| 4 | 2026-11-20 | Desktop-level `NSPanel`, all Spaces; spike in phase 4 to confirm mouse events | 0004 |
| 5 | 2026-11-20 | XcodeGen-generated project; `.xcodeproj` not committed | 0005 |
| 6 | 2026-11-20 | Particles via `CAEmitterLayer` | 0006 |
| 7 | 2026-11-20 | Any number of currencies (not fixed to 5); base currency changeable | — |
| 8 | 2026-11-20 | Distribution: signed + notarized DMG for friends; no App Store | — |
| 9 | 2026-11-20 | No CI; `.github/` holds PR + issue templates only | — |
| 10 | 2026-11-20 | No bonus tier; all features core | — |
| 11 | 2026-11-20 | Build with Xcode 26 or newer (27.2 installed); target stays macOS 26.0 | 0007 |
| 12 | 2026-11-20 | Bundle ID and defaults suite `com.afik.CurrencyNotch` | 0008 |
| 13 | 2026-11-20 | Crypto rates display with 5 decimals (`0.00000`) | 0009 |
| 14 | 2026-11-20 | Base currency is never in the watch list; base change removes it | 0010 |
| 15 | 2026-11-20 | Mocks in a `CurrencyCoreTestSupport` target, never linked into the app | 0011 |
| 16 | 2026-11-20 | Versioned persistence envelopes; decimals stored as strings | 0012 |
| 17 | 2026-11-20 | Frankfurter v2 flat-array shape recorded; fallback drops crypto | 0013 |
| 18 | 2026-11-20 | Intraday history 48 h, daily 35 d; 24h series seeded from yesterday's daily value | 0014 |
| 19 | 2026-11-20 | Desktop level confirmed on macOS 26; `.fullScreenNone` removed (it hides the window) | 0004 |
| 20 | 2026-11-20 | One pill with per-display positions + last-used display; global position lock | 0015 |
| 21 | 2026-11-20 | Display precision rule (≥1000: 2 dp; <1: ≥4 significant digits); full interval after resume | 0016 |
| 22 | 2026-11-20 | Hover/dropdown state machine, grow-then-shrink resizing, Esc via key-capable panel, monogram crypto icons | 0017 |
