# ADR-0002: Live data from day one, key-less providers

- Status: Accepted · Date: 2026-11-20

## Context
The workshop says "mock data only". The owner wants real rates from the first build. Friends get
the app, so it must not depend on an API key (a key would end up in the binary or require a server).

## Decision
- Primary: Coinbase public `GET /v2/exchange-rates?currency=<BASE>` (no auth, fiat + crypto, near-live).
- Fallback + fiat history: Frankfurter v2 (no auth, open source, daily history).
- Crypto history: Coinbase historic spot price (`/v2/prices/<PAIR>/spot?date=`).
- Mocks/fixtures are used only in tests; tests never touch the network.

## Consequences
- Fiat rates may update less often than the refresh interval. The UI shows "Updated …" honestly.
- Endpoint shapes must be verified in Phase 3 and recorded as fixtures; any change → new ADR.
- If a source adds auth, switch provider behind the `RateProvider` protocol.
