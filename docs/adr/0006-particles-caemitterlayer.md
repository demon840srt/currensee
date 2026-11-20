# ADR-0006: Particle effects with CAEmitterLayer

- Status: Accepted · Date: 2026-11-20

## Context
Ice, Fire and Israel themes need full particle effects (snow, sparks, sparkles) inside a tiny,
always-visible window, without draining the battery.

## Decision
Use Core Animation `CAEmitterLayer` hosted in an `NSView` (wrapped with `NSViewRepresentable`),
masked to the pill shape. No SpriteKit, no per-frame SwiftUI `Canvas`.

## Consequences
- GPU-composited, low CPU. Pausing is cheap (`birthRate = 0` / `speed = 0`).
- Effect tuning lives in `references/themes.md` and a `ThemeSpec` struct, so it's easy to tweak.
