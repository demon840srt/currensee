# ADR-0004: Desktop-level NSPanel on all Spaces

- Status: Accepted (spike done in Phase 4) · Date: 2026-11-20

## Context
The owner chose "desktop level" (under app windows), not always-on-top. The pill must still
receive hover, click, drag and right-click events when not covered.

## Decision
Borderless, non-activating `NSPanel` at a level just above desktop icons
(`CGWindowLevelForKey(.desktopIconWindow) + 1`), `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`,
`hidesOnDeactivate = false`, `LSUIElement = YES`.

## Fallback (if the spike shows lost mouse events)
Use `.normal` level with the same collection behavior and `orderBack` on activation of other apps,
so it behaves as "below other windows" while staying interactive. Record the result here.

## Spike result (2026-11-20, macOS 26.6, Xcode 27.2)
- **Mouse events work at desktop-icon level + 1.** Verified on hardware by the owner with the Debug pointer log
  (`com.afik.CurrencyNotch` / `pointer`): hover enter/exit (23 events), clicks, drags, right-click menu, a locked
  drag ignored while a click still worked. Synthetic `CGEvent`s from the build shell were dropped (no
  Accessibility permission), so the check had to be manual.
- **`.fullScreenNone` hides the window on macOS 26** (`kCGWindowIsOnscreen = false`) at every level, normal level
  included; it was removed. Final behavior: `[.canJoinAllSpaces, .stationary, .ignoresCycle]`.
- Like Finder's desktop icons, the pill is not visible in a Space showing a full-screen app. Expected for desktop level.
- The fallback (normal level + `orderBack`) is **not needed**.
