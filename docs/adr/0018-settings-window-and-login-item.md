# ADR-0018: Settings window, preferences editor, login item, Show/Hide

- Status: Accepted · Date: 2026-11-20 · Adds `isPillHidden` to `AppSettings` (SPEC §4)

## Decision
- **One entry point for changes**: `PreferencesEditor` (core) validates, saves immediately and returns the effects
  the app must apply (reconfigure rates, refresh now, rotation list/interval, summaries, login item, appearance,
  formatting, pill visibility, lock). The app layer only applies effects.
- **Settings window**: an AppKit `NSWindow` hosting SwiftUI (`SettingsView`), opened from the shared menu; more
  reliable than the SwiftUI `Settings` scene for an `LSUIElement` app. Tabs: Currencies, Display, Alerts
  (placeholder until Phase 9), General. Refresh interval choices: 1, 2, 5, 10, 15, 30 min.
- **Catalog search** matches code and name in the UI language and English, case/accent-insensitive; ranking
  exact code → exact name → code prefix → name prefix → contains.
- **Launch at login** (`SMAppService.mainApp`): the toggle always shows the real service status
  (`requiresApproval` shows a hint and a button to System Settings › Login Items). SPEC §4 defaults it to on, so
  the app registers **once**, on the **first Release launch** (`SettingsStore.loginItemAttempted`); Debug builds
  never register automatically.
- **Show/Hide pill** persists across launches (`AppSettings.isPillHidden`).

## Consequences
- Running a Release build from the build folder on a development Mac registers that copy as a login item
  (observed in Phase 7: background-items entry `enabled`; after switching the Settings toggle off it became
  `disabled`, confirming the toggle drives the real `SMAppService` state). Afterwards turn launch at login on
  from the installed app's Settings. Measure performance with Debug builds, or switch the toggle off right away.
- `defaults read/export <container plist path>` does not show a sandboxed app's live values (they're held by
  the preferences service); inspect settings through the app, not the plist file.
- Measured (Release, macOS 26.6): physical footprint 22.5 MB; settled CPU avg 2.1 % with rotation every 5 s —
  marginally above the 2 % target; to be reduced in Phase 8's performance pass.
