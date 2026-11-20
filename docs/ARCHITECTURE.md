# Currency Notch — Architecture

## Overview
A single native macOS app. There is no server and no database. The workshop's
`backend/` + `frontend/` names are kept, but both run in the same process:

```
┌──────────────────────── CurrencyNotch.app (frontend/) ────────────────────────┐
│  AppDelegate / @main App (LSUIElement, menu bar NSStatusItem)                │
│  PillPanelController (NSPanel, desktop level, drag/lock, per-screen origin)  │
│  SwiftUI views: PillView · ExpandedView · DropdownView · SettingsWindow      │
│  ThemeLayer (CAEmitterLayer via NSViewRepresentable) · SplitFlapText         │
│  Notifier (UNUserNotificationCenter) · LoginItem (SMAppService)              │
│  Localizable.xcstrings (he default, en, es, ru, zh-Hans)                     │
└───────────────▲──────────────────────────────────────────────────────────────┘
                │ @Observable AppModel (MainActor) — the only bridge
┌───────────────┴────────── CurrencyCore (backend/, Swift package) ─────────────┐
│  Models: Currency, RateQuote, HistoryPoint, WatchList, RateAlert, …          │
│  RateProvider protocol → CoinbaseProvider · FrankfurterProvider · Mock…      │
│  RateService (actor): polling, backoff, fallback, validation, staleness      │
│  HistoryStore (actor): snapshots, daily series, change %, sparkline points   │
│  RotationEngine: order, interval, pause/resume → current index stream        │
│  AlertEvaluator: crossing detection, arm/disarm                              │
│  SettingsStore: UserDefaults Codable wrapper · DiskCache: Application Support│
│  RateHostAllowlist · ResponseValidator                                       │
└───────────────────────────────────────────────────────────────────────────────┘
          │ HTTPS (URLSession, ATS, allowlist, 10 s timeout, 1 MB cap)
   api.coinbase.com (primary, fiat+crypto)   api.frankfurter.dev (fallback + fiat history)
```

## Folder layout
```
/backend/CurrencyCore/
  Package.swift
  Sources/CurrencyCore/{Models,Catalog,Providers,Services,Persistence,Security}/
  Sources/CurrencyCoreTestSupport/   # mocks for tests only, never linked into the app (ADR-0011)
  Tools/generate-catalog.swift       # regenerates Catalog/currencies.json
  Tests/CurrencyCoreTests/ (+ Fixtures/*.json recorded responses)
/frontend/CurrencyNotch/
  project.yml                # XcodeGen spec; depends on ../../backend/CurrencyCore
  Sources/{App,Window,Views,Themes,Settings,System}/
  Resources/{Assets.xcassets,Localizable.xcstrings,Info.plist,CurrencyNotch.entitlements}
  Tests/CurrencyNotchTests/  # thin app-level tests (view models, placement math)
/scripts/  bootstrap.sh test.sh build.sh run.sh release.sh
/docs/     SPEC.md ARCHITECTURE.md build-plan.md adr/
/references/  rate-apis.md themes.md ui-sizes.md
/.claude/  settings.json commands/phase.md
/.github/  pull_request_template.md ISSUE_TEMPLATE/
```

## Key flows
1. **Launch:** load settings → load `cache.json` and show it immediately → restore placement for current screen → start `RateService` + `RotationEngine`.
2. **Refresh:** timer/wake/network → `CoinbaseProvider.fetch(base)` → `ResponseValidator` → invert to "price in base" → `HistoryStore.record` → `AlertEvaluator.evaluate` → publish to `AppModel`. Two failures in a row → `FrankfurterProvider` for fiat.
3. **Rotate:** `RotationEngine` ticks every N s unless paused (hover/dropdown) → `SplitFlapText` animates to new string.
4. **Interact:** mouse down → track delta → < 4 pt = click (toggle dropdown) · ≥ 4 pt and unlocked = drag → on mouse up save `WidgetPlacement` for that screen's `CGDirectDisplayID`-based ID.

## Concurrency
Swift 6 strict concurrency. Network and stores are `actor`s; `AppModel` is `@MainActor @Observable`.
No `DispatchQueue` in new code unless AppKit requires it.

## Persistence
- UserDefaults (suite `com.afik.CurrencyNotch`, ADR-0008): settings, watch list, alerts, placements — all `Codable` with a schema `version` field.
- Application Support `CurrencyNotch/`: `cache.json`, `history.json`. Writes are atomic.

## Testing strategy
- `CurrencyCore`: Swift Testing; providers tested against recorded fixtures through an injected `HTTPClient` protocol (no network). Covers inversion math, validation, fallback, backoff, staleness, rotation, alerts, history downsampling and pruning.
- App: placement math (screen bounds, missing display), click-vs-drag threshold, view-model formatting per locale (he/ru/zh decimals), RTL snapshot sanity.
- Manual checklist per phase for visuals (themes, multi-display, Spaces).

## Distribution
Personal use (ADR-0023): `release.sh` → `xcodegen` → `xcodebuild build` (Release, ad-hoc signed, Hardened Runtime,
sandbox) → verify with `codesign` → install to `/Applications/CurrencyNotch.app`; `--dmg` also writes a backup DMG
to `dist/`. No Developer ID, notarization or secrets.
