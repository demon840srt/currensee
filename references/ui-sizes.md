# UI sizes and behavior (starting values)

| State | Size (pt) | Notes |
|---|---|---|
| Collapsed | ≈ 200 × 34 | About the size of a 14"/16" MacBook Pro notch |
| Hover expanded | ≈ 280 × 64 | Grows symmetrically from the pill's center; clamped on screen |
| Dropdown | 280 × (rows × 28 + 16), max 10 visible rows then scroll | Opens below; upward if not enough room |

Timings: hover-in delay 300 ms · hover-out 200 ms · split-flap ≈ 0.4 s · expand spring ≈ 0.35 s.
Click vs drag threshold: 4 pt.

Collapsed layout (LTR): `[flag] USD  3.7012 ₪  •stale`
Collapsed layout (RTL, Hebrew): mirrored container. Code and number stay LTR-isolated.

Add screenshots or sketches to this folder as you iterate; Claude reads `references/` as input only.
