# ADR-0009: Crypto rates use 5 decimals

- Status: Accepted · Date: 2026-11-20 · Supersedes the "2 for crypto" part of SPEC §4

## Context
SPEC §4 set 2 decimals for JPY and crypto. With 2 decimals, low-priced coins (e.g. SHIB in ILS) display as `0.00`.

## Decision
Owner decision: crypto currencies display with **5 decimals** (`0.00000`). Fiat stays at 4, JPY at 2.
Stored in the bundled catalog's `decimals` field and enforced by `CurrencyCatalogTests.decimalsFollowRule`.

## Consequences
- BTC/ETH show 5 decimals too (e.g. `341234.56000`); the Phase 5 formatter may trim trailing zeros
  for large values if that reads better, recorded in a new ADR if so.
