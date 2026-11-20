# Theme specs (starting values — tune visually in Phase 8)

All themes: pill corner radius = height / 2; text SF Pro Rounded semibold, monospaced digits;
contrast ≥ 4.5:1. Particles are clipped to the pill/dropdown shape.

## Ice
- Background: linear gradient top→bottom `#EAF7FF` → `#9FD8FF` → `#5DB7F0`; 1 pt rim `#FFFFFF` at 70%.
- Text: `#0B2A44`. Change ▲ `#0F7B3F`, ▼ `#B3261E`.
- Particles: snowflakes, white, size 1.5–3 pt, birthRate ~6/s, velocity 8–14 pt/s downward,
  slight horizontal drift, spin, lifetime ~5 s. Plus a slow shimmer gradient sweeping the rim every 4 s.

## Fire
- Background: radial/linear `#3A0603` → `#B3200E` → `#FF7A1A` → `#FFC24A` at the bottom edge.
- Text: `#FFF6E5` with a soft dark shadow. ▲ `#9CFF9C`, ▼ `#FFD1C9`.
- Particles: sparks rising from the bottom, `#FFB347`/`#FF6A00`, size 1–2.5 pt, birthRate ~10/s,
  velocity 12–24 pt/s up, fade out; ember glow = background brightness flicker ±6% at irregular 0.1–0.4 s.

## Israel (blue & white)
- Background: `#FFFFFF`; two horizontal stripes flag-blue `#0038B8`, each ~12% of the height,
  inset from top and bottom; a subtle Star of David watermark at 6% opacity behind the text.
- Text: `#0038B8`. ▲ `#0F7B3F`, ▼ `#B3261E`.
- Particles: drifting sparkles alternating `#0038B8` / `#FFFFFF` (white with a blue glow), size 1–2 pt,
  birthRate ~5/s, slow float; stripes get a waving shimmer (gradient offset animation, 3 s loop).

## Classic Black Notch
- Background `#000000`, no rim, no particles. Text `#FFFFFF`. ▲ `#30D158`, ▼ `#FF453A`.
- When placed top-center under a notch, it should look like the notch itself.

## Frosted Glass
- macOS 26 Liquid Glass via SwiftUI `.glassEffect()` in a capsule; follows light/dark appearance.
- Text: primary label color. No particles.

## Motion and power
- Reduce Motion: particles off; split-flap → 0.25 s crossfade.
- Battery / Low Power Mode with "pause effects on battery": emitter `birthRate = 0` (existing particles finish).
- Occluded (window fully covered): pause emitters and shimmer.
