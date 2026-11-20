# ADR-0020: Particles stepped at a capped frame rate (supersedes the emitter part of ADR-0006)

- Status: Accepted · Date: 2026-11-21

## Context
ADR-0006 chose `CAEmitterLayer`. Measured in Phase 8 (Debug, macOS 26.6, ProMotion display, 60 s windows):
the app's own CPU stayed low, but **WindowServer** rose from ≈ 14 % to ≈ 44–46 % with particles running on
Ice, Fire or Israel. Splitting the Ice theme showed particles alone cost +23–32 points; the shimmer ≈ +3.
`CAEmitterLayer` has no frame-rate control, so the compositor redraws the window at the full refresh rate.

## Decision
- Particles are simulated by `ParticleSimulation` (core, unit-tested: spawn rate, lifetime, bounds, fading,
  draining when paused, determinism) and drawn as ≤ 40 sprite layers moved by a `CADisplayLink` capped at
  **12 fps** (`preferredFrameRateRange`). Sprites are drawn in code, one image per color (glow baked in).
- Shimmer and flicker stay Core Animation animations with `preferredFrameRateRange` capped at 12 fps.
- Pausing stops spawning; the display link keeps stepping until live particles finish, then pauses itself.
  It is invalidated when the view leaves its window.

## Measurements (Debug, 60 s windows, WindowServer = whole compositor)
| Configuration | App | WindowServer |
|---|---|---|
| Classic, no particles (before / after) | 0.13 % / 0.15 % | 4.9 % / 5.2 % |
| Ice — CAEmitterLayer (120 Hz) | 1.25 % | 44.7 % (baseline that run 14.7 %) |
| Ice — 24 fps simulation | 4.6 %* | 22.9 % (baseline 7.8 %) |
| Ice — 12 fps simulation | 2.0 % | 10.5 % |
| Fire — 12 fps simulation | 0.8 % | 15.1 % |
\* included a rate refresh. The extra compositor cost fell from ≈ +30 to ≈ +5–10 points.

## Consequences
- Slow snow (8–14 pt/s) moves ≈ 1 pt per frame at 12 fps; sparks ≈ 1–2 pt. If it looks choppy, 24 fps roughly
  doubles the compositor cost — a one-constant change (`ParticleSimulation.preferredFramesPerSecond`).
- Fire costs more than Ice because the ember flicker redraws the whole surface.
