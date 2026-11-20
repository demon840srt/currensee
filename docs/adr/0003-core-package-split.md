# ADR-0003: backend/ = CurrencyCore package, frontend/ = macOS app, no DB

- Status: Accepted · Date: 2026-11-20

## Context
The workshop structure expects `/backend` and `/frontend` and an architecture of db + backend + frontend.
The app has no server and stores very little data.

## Decision
- `backend/CurrencyCore`: a Swift package with all non-UI logic, fully unit-tested with `swift test`.
- `frontend/CurrencyNotch`: the SwiftUI/AppKit app, thin, depends on the package locally.
- No database: settings in UserDefaults, cache and history as JSON in Application Support.

## Consequences
- Keeps the workshop folder names and makes the logic testable without the UI.
- "backend" doesn't mean a server here; ARCHITECTURE.md states this explicitly.
