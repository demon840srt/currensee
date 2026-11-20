# ADR-0013: Frankfurter v2 response shape; fallback serves fiat only

- Status: Accepted · Date: 2026-11-20 · Required by ADR-0002 ("any change → new ADR")

## Context
Verified live on 2026-11-20 (fixtures in `backend/CurrencyCore/Tests/CurrencyCoreTests/Fixtures/`):
- Frankfurter v2 returns a **flat array** `[{"date","base","quote","rate"}]` with `rate` as a JSON **number**
  (the reference notes implied an object). Swift's `JSONDecoder` decodes such numbers into `Decimal` exactly.
- Latest rates (`/v2/rates?base=ILS`) include ~45 crypto codes (daily values) and rows dated today or yesterday.
- Ranges (`from`/`to`) include every calendar day, weekends too. Unknown base → HTTP 422.
- Coinbase unknown base → HTTP 400; unknown spot pair → HTTP 404.

## Decision
- `FrankfurterProvider` decodes rows individually (bad rows skipped) and **drops every non-fiat code**.
  The fallback serves fiat only, as SPEC F17 says; crypto keeps its last Coinbase value and shows as stale.
- HTTP 400 (Coinbase) and 404/422 (Frankfurter) map to `RateError.unsupportedBase`.
- `fetchedAt` is the time we fetched, not Frankfurter's rate date, so staleness reflects connectivity.

## Consequences
- During fallback, fiat values move by ~1% (central-bank daily rate vs Coinbase near-live). Below the 50% jump hold.
