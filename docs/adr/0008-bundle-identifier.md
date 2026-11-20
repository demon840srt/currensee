# ADR-0008: Bundle identifier `com.afik.CurrencyNotch`

- Status: Accepted · Date: 2026-11-20

## Context
The architecture used a placeholder `com.<you>.CurrencyNotch` for the bundle ID and UserDefaults suite.

## Decision
- App bundle ID and UserDefaults suite: `com.afik.CurrencyNotch`.
- Test bundle: `com.afik.CurrencyNotchTests`.

## Consequences
- Changing it later would orphan saved settings, placements and alerts (new defaults domain and sandbox
  container), so it should stay fixed once friends install the app.
- Developer ID signing does not require the ID to be registered in advance.
