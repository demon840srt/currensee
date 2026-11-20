# ADR-0016: Rate display precision, split-flap board, rotation timing

- Status: Accepted · Date: 2026-11-20 · Refines ADR-0009

## Context
Applying catalog decimals literally gave `BTC 194557.83200 ₪`, `SHIB 0.00001 ₪` and `JPY 0.02 ₪`.

## Decision
- **Precision** (`RateFormatter`):
  - value ≥ 1000 → 2 decimals with locale grouping (`BTC 194,557.83 ₪`);
  - 1 ≤ value < 1000 → catalog decimals (fiat 4, JPY 2, crypto 5: `USD 3.3429 ₪`, `SOL 512.34568 ₪`);
  - value < 1 → catalog decimals but at least 4 significant digits (`JPY 0.02109 ₪`, `SHIB 0.00001177 ₪`), max 12.
  - Locale decimal/grouping separators (he, en, es, ru, zh-Hans); bidi control marks stripped — the view isolates
    numbers LTR. Missing data shows `—`.
- **Board**: three split-flap segments — code (leading-aligned, letter-wide cells), value (trailing-aligned,
  digit-wide cells), base symbol — each padded to the widest value in the watch list so the pill never changes
  width while rotating. Font stays SF Pro Rounded semibold with monospaced digits. Flip ≈ 0.4 s staggered
  per changed cell; Reduce Motion → 0.25 s crossfade.
- **Rotation timing**: after hover/dropdown ends, an interval change, or a change of the shown code, the timer
  restarts so the current code stays for a full interval (no flip right as the mouse leaves).

## Consequences
- Measured on the Debug build (macOS 26.6): idle CPU avg 1.4 % with rotation at 5 s, peaks ≈ 11 % during a flip;
  memory 73 MB.
