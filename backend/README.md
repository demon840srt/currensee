# backend/

Holds the `CurrencyCore` Swift package: all non-UI logic (models, rate providers, rotation,
history, alerts, persistence, validation). Created in Phase 1. See `docs/adr/0003-core-package-split.md`.

"backend" here does **not** mean a server. It runs inside the app process.
