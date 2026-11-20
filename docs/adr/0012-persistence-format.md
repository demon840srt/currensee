# ADR-0012: Persistence format — versioned envelopes, decimals as strings

- Status: Accepted · Date: 2026-11-20

## Decision
- Every persisted value (UserDefaults keys and Application Support JSON files) is wrapped as
  `{"version": N, "value": …}`. A different version, bad JSON or invalid content loads as the default — never a crash.
- `Decimal` fields are encoded as strings (`"3.7012"`) and parsed strictly with the POSIX locale, so money
  never passes through `Double` in JSON.
- `AppSettings` decodes leniently per field: one unknown value (e.g. a future theme) resets only that field.
- Cache files larger than 8 MB are ignored as corrupt. Writes are atomic.

## Consequences
- A future schema change bumps the version and adds an explicit migration; until then old data resets to defaults.
