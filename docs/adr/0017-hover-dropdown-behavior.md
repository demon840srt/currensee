# ADR-0017: Hover expand and dropdown behavior

- Status: Accepted · Date: 2026-11-20

## Decision
- **State machine** (`PillInteraction`): collapsed ⇄ expanded on hover (300 ms in / 200 ms out via `HoverDelay`);
  click toggles the dropdown; click outside or Esc closes it; leaving the pill does not close an open dropdown.
  The dropdown opens under (or above) the **expanded** pill, which stays expanded while it's open.
  Rotation pause reasons (hover, dropdown) are derived from the state.
- **Resizing**: the window grows to the target frame at once (the new area is transparent while SwiftUI springs
  in, 0.35 s) and shrinks only after the content animated out, so the window always matches what's visible and
  clicks never land on invisible areas. Expanded grows around the pill's center, clamped on screen; the dropdown
  opens below if it fits, else above, else on the roomier side with a shorter, scrolling list.
- **Drag** while expanded saves the collapsed pill centered where it was dropped; dragging is disabled while the
  dropdown is open.
- **Esc**: while the dropdown is open the non-activating panel may become key (without activating the app) so it
  receives Esc; focus is handed back when it closes. A global *key* monitor would need Accessibility permission.
- **Click outside**: a global *mouse* monitor (no permission needed) while the dropdown is open.
- **Icons**: fiat flag emoji; BTC uses the `bitcoinsign` SF Symbol; other crypto get a monogram badge (catalog
  symbol if one character, e.g. Ξ, else the first letter) with a deterministic hue. No third-party logos.
- Change colors follow Classic Black Notch (▲ `#30D158`, ▼ `#FF453A`, = grey) until per-theme colors in Phase 8.
