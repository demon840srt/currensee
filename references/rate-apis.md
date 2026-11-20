# Rate API reference notes

Checked 2026-11-20. **Verify the live response shapes in Phase 3 before recording fixtures.**

## Primary — Coinbase public data API (no auth)
- Current rates: `GET https://api.coinbase.com/v2/exchange-rates?currency=<BASE>`
  - Response: `{"data":{"currency":"ILS","rates":{"USD":"0.27","BTC":"0.0000029",...}}}`; values are **strings**.
  - `rates[X]` = units of X per **1 BASE**. Displayed price of X in BASE = `1 / rates[X]` (use `Decimal`).
  - Covers fiat and crypto. Near-live.
- Currencies: `GET /v2/currencies` (fiat), `GET /v2/currencies/crypto` (crypto) — use to build/refresh the catalog.
- Historic spot (crypto history): `GET /v2/prices/<CODE>-<BASE>/spot?date=YYYY-MM-DD`.
- Be polite: at most 1 current-rates call per refresh, and history calls at most once a day per currency, cached.

## Fallback + fiat history — Frankfurter v2 (no auth, open source)
- Latest: `GET https://api.frankfurter.dev/v2/rates?base=<BASE>&quotes=USD,EUR,...`
- Date: `GET /v2/rates?date=YYYY-MM-DD`
- Range: `GET /v2/rates?from=YYYY-MM-DD&to=YYYY-MM-DD&base=<BASE>&quotes=...`
- Many central-bank sources; history goes back to 1948. Mostly daily data, so don't expect minute-level changes.
- v1 (`/v1/latest`) is deprecated but still available.
- Self-hostable (Docker) if ever needed. Not planned (ADR-0001).

## Rules for the implementation
- Allowlist: `api.coinbase.com`, `api.frankfurter.dev`. Anything else → reject.
- Timeout 10 s, body cap 1 MB, `Accept: application/json`, `User-Agent: CurrencyNotch/<version>`.
- Parse numbers from strings into `Decimal(string:locale: POSIX)`. Reject nil, ≤ 0 and absurd values.
- Never log full bodies in Release.
