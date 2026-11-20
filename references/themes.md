# Theme specs (final values after Phase 8 — source of truth is `ThemeRegistry.swift`)

All themes: pill corner radius = height / 2; text SF Pro Rounded semibold, monospaced digits;
contrast ≥ 4.5:1 for every text role, verified by `ThemeTests` (ADR-0019). Particles are clipped to the
pill/dropdown shape. Colors marked *(adjusted)* changed from the starting values to pass contrast.

## Ice
- Background: linear gradient top→bottom `#EAF7FF` → `#C4E7FF` (55%) → `#9FD8FF` (85%) → `#5DB7F0` (100%)
  *(adjusted: deep blue only at the bottom edge)*; 1 pt rim `#FFFFFF` at 70%. Dropdown: `#EAF7FF`.
- Text: `#0B2A44`. Change ▲ `#085C2D`, ▼ `#9E1F18` *(adjusted)*. Secondary / flat `#3A5870`; warning `#7A3E00`.
- Particles: snowflakes, white, size 1.5–3 pt, birthRate ~6/s, velocity 8–14 pt/s downward,
  slight horizontal drift, spin, lifetime ~5 s. Plus a slow shimmer gradient sweeping the rim every 4 s.

## Fire
- Background: linear `#3A0603` → `#7E150A` (45%) → `#B3200E` (80%) → `#FF7A1A` (92%) → `#FFC24A` (100%)
  *(adjusted: the orange/amber glow is a thin band below the text)*. Dropdown: `#3A0603` → `#4A0A05`.
- Text: `#FFF6E5` with a soft dark shadow. ▲ `#9CFF9C`, ▼ `#FFD1C9`. Secondary / flat `#F5DCCB`; warning `#FFD27A`.
- Particles: sparks rising from the bottom, `#FFB347`/`#FF6A00`, size 1–2.5 pt, birthRate ~10/s,
  velocity 12–24 pt/s up, fade out; ember glow = background brightness flicker ±6% at irregular 0.1–0.4 s.

## Israel (blue & white)
- Background: `#FFFFFF`; two horizontal stripes flag-blue `#0038B8`, each 12% of the height,
  at 4–16% and 84–96% (clear of the text band); a subtle Star of David watermark at 6% opacity behind the text.
- Text: `#0038B8`. ▲ `#0F7B3F`, ▼ `#B3261E`. Secondary / flat `#4C64A0` *(adjusted)*; warning `#7A3E00`.
- Particles: drifting sparkles alternating `#0038B8` / `#FFFFFF` (white with a blue glow), size 1–2 pt,
  birthRate ~5/s, slow float; stripes get a waving shimmer (gradient offset animation, 3 s loop).

## Classic Black Notch
- Background `#000000`, no rim, no particles. Text `#FFFFFF`. ▲ `#30D158`, ▼ `#FF453A`.
  Secondary `#B3B3B3`, flat `#999999`, warning `#FF9F0A`.
- When placed top-center under a notch, it should look like the notch itself.

## Frosted Glass
- macOS 26 Liquid Glass via SwiftUI `.glassEffect()` in a capsule; follows light/dark appearance.
- Text: primary label color. No particles. Change colors per appearance *(adjusted)*: light ▲ `#18692C`
  ▼ `#A1241B`; dark ▲ `#30D158` ▼ `#FF8A80`. Secondary `#3C3C43` (light) / `#AEAEB2` (dark).

## Motion and power
- Reduce Motion: particles off; split-flap → 0.25 s crossfade.
- Battery / Low Power Mode with "pause effects on battery": emitter `birthRate = 0` (existing particles finish).
- Occluded (window fully covered): pause emitters and shimmer.
- Split-flap, shimmer and flicker are Core Animation (render server; shimmer/flicker capped at 12 fps). Particles
  are a small simulation stepped at 12 fps by a display link (ADR-0020) — `CAEmitterLayer` cost ≈ +30 % WindowServer CPU.
