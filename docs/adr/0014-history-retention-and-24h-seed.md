# ADR-0014: History retention and 24h seeding

- Status: Accepted · Date: 2026-11-20

## Decision
- **Intraday** snapshots (15-minute buckets, last value wins) are kept **48 hours**; **daily** points (00:00 UTC)
  are kept **35 days**. This stays within SPEC F21's 35-day limit and keeps `history.json` small.
- **24h range:** until the snapshots reach back to the start of the 24h window (within 4 h), the series is seeded
  with the most recent daily point from 12–72 h ago, so change % and a basic sparkline appear immediately.
- **7d / 30d:** daily points since 00:00 UTC 7 / 30 days ago, plus the current value.
- Change % = (current − first) / first × 100, rounded to 2 decimals; direction from the rounded value.
  "Collecting" when there is no current value or fewer than 2 points. Sparklines have at most 48 points.
- Daily history is fetched once per UTC day per currency (retry hourly after a failure), backfilling up to
  31 days and only the missing days (Coinbase spot = one call per day per coin).
