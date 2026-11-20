# ADR-0015: One pill, per-display positions, global lock

- Status: Accepted · Date: 2026-11-20 · Changes the `WidgetPlacement` and `AppSettings` entities in SPEC §4

## Context
SPEC says the pill "shows on every display" and also that its position is "saved per display; if that display
is gone, it moves to the main display". `WidgetPlacement` also had an `isLocked` field per display.

## Decision
- **One pill.** It can be dragged to any display; its position is remembered for each display, plus the
  last-used display (`SettingsStore.lastScreenID`). At launch or when displays change it goes to its spot on
  the last-used display if connected, else its spot on the main display, else main top-center — always clamped
  fully on screen (`PlacementResolver`). Restoring onto a fallback display does not overwrite the last-used one,
  so the pill returns when that display is reconnected.
- Displays are identified by their hardware UUID (`CGDisplayCreateUUIDFromDisplayID`), not the display number.
  "Main" means the primary (menu-bar) display, not `NSScreen.main`.
- **Global lock**: `AppSettings.isPositionLocked` (default off). `WidgetPlacement` is now `screenID, originX, originY`.
  Old saved placements with an `isLocked` key still decode (the key is ignored).

## Consequences
- No duplicate pills rotating out of sync; one lock switch behaves the same on every display.
