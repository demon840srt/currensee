# ADR-0004: Desktop-level NSPanel on all Spaces

- Status: Accepted (pending Phase 4 spike) · Date: 2026-11-20

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

## Spike result
_To be filled in Phase 4._
