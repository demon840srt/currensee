# ADR-0010: The base currency is never in the watch list

- Status: Accepted · Date: 2026-11-20

## Context
A watch-list entry equal to the base always shows `1`. SPEC didn't say what happens when the base changes
to a currency that's already in the list.

## Decision
- `WatchList` rejects the base inside `orderedCodes` (`WatchListError.containsBase`).
- `changeBase(to:)` removes the new base from the list; if that leaves it empty, the old base is put in its place.

## Consequences
- The list is always valid (≥ 1, unique, no base), so the rotation never shows a meaningless `1`.
