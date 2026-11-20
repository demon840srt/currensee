# ADR-0019: Themes, contrast adjustments, Core Animation for motion

- Status: Accepted · Date: 2026-11-20 · Adjusts colors in references/themes.md

## Context
- Phase 7 measured ≈ 2.1–2.3 % settled CPU; profiling showed SwiftUI re-laying out the pill on every frame of
  the split-flap animation (main thread), nothing else.
- Several `themes.md` colors fail SPEC F27 (text ≥ 4.5:1): Fire's cream text on orange/amber (≈ 1.6–2.4:1),
  Ice's ▲/▼ on mid blue (≈ 2.4–3.4:1), and 60–70 %-opacity secondary text on Ice, Fire and Israel.

## Decision
- **Motion off the SwiftUI frame loop**: the split-flap board is `CATextLayer` cell pairs animated with
  `CABasicAnimation` (`SplitFlapBoard`); shimmer/flicker are `CAGradientLayer` / `CAKeyframeAnimation`
  (render server); particles are a capped-frame-rate simulation (ADR-0020). SwiftUI only updates on data changes.
  Result: settled app CPU **0.16–0.31 %** (was ≈ 2.3 %); memory footprint 18.7 MB.
- **Themes are data** (`ThemeSpec`/`ThemeRegistry` in core): backgrounds, rim, six text roles (primary,
  secondary, up, down, flat, warning), particles, effects. Frosted Glass has light/dark variants; the others
  don't vary with appearance.
- **Contrast is tested**: every text role vs every color behind text — the pill's text band (20–80 % of its
  height, gradients sampled at 13 points) and the whole dropdown list background — must be ≥ 4.5:1. Glass is
  checked against typical light/dark material tints.
- **Color adjustments** (minimal, look preserved):
  - Ice: gradient `#EAF7FF → #C4E7FF (55%) → #9FD8FF (85%) → #5DB7F0 (100%)` (deep blue only at the bottom edge);
    ▲ `#085C2D`, ▼ `#9E1F18`, secondary/flat `#3A5870`, warning `#7A3E00`; list `#EAF7FF`.
  - Fire: gradient `#3A0603 → #7E150A (45%) → #B3200E (80%) → #FF7A1A (92%) → #FFC24A (100%)` (glow is a thin band
    below the text); secondary/flat `#F5DCCB`, warning `#FFD27A`; list `#3A0603 → #4A0A05`.
  - Israel: secondary/flat `#4C64A0`, warning `#7A3E00`; stripes sit at 4–16 % and 84–96 % of the height, clear of
    the text band.
  - Classic: secondary `#B3B3B3`, flat `#999999`, warning `#FF9F0A`.
  - Frosted Glass: light ▲ `#18692C` ▼ `#A1241B`; dark ▼ `#FF8A80`; secondary `#3C3C43` / `#AEAEB2`.
- **Effects policy** (`EffectsPolicy`): Reduce Motion and full occlusion always pause; battery and Low Power Mode
  pause when "pause effects on battery" is on; themes without effects never run them. Pausing sets emitter
  `birthRate = 0` (existing particles finish) and freezes shimmer timelines. Inputs are event-driven
  (IOKit power-source notifications, `NSProcessInfoPowerStateDidChange`, accessibility display options,
  window occlusion) — no polling.
- **Debug-only measurement overrides**: `CURRENCY_NOTCH_THEME=<id>` and `CURRENCY_NOTCH_IGNORE_BATTERY=1`
  (environment variables, compiled out of Release, never saved).
- Particle images are drawn in code (snowflake, soft spark, four-point sparkle): no image assets or third-party art.
