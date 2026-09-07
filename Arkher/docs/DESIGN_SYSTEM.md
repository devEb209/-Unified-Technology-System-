# ARKHER Design System — the palette, in numbers

Every colour, spacing value and type size used by ARKHER lives in one place:
**`src/ui/theme.lua`** (`arkher/ui/theme`). It returns plain numbers — never Roblox objects —
so it is testable headless and reusable by any adapter: the engine HUD, ARKHER Studio, the
Studio plugin surface and any game UI built on ARKHER.

Design intent: **an instrument panel in a dark cockpit**. Deep neutral blues (never pure black,
so OLED phones do not smear on scroll), exactly one signal accent, and three status colours that
still read on a phone screen in daylight.

---

## 1. Raw tokens

| Token | Hex | RGB | Where it is used |
|---|---|---|---|
| `void` | `#0A0C12` | 10, 12, 18 | HUD backdrop |
| `abyss` | `#12141A` | 18, 20, 26 | app background |
| `slate900` | `#1A1D26` | 26, 29, 38 | panels |
| `slate800` | `#232734` | 35, 39, 52 | raised panels, inputs |
| `slate700` | `#28303E` | 40, 48, 62 | progress tracks, dividers |
| `slate600` | `#3A4356` | 58, 67, 86 | borders |
| `slate400` | `#94A3B8` | 148, 163, 184 | muted text |
| `slate200` | `#D7E1F0` | 215, 225, 240 | body text |
| `white` | `#F2F6FF` | 242, 246, 255 | emphasis text |
| **`arkherBlue`** | **`#60B0FF`** | 96, 176, 255 | **the signal accent** |
| `arkherDeep` | `#2B6FD4` | 43, 111, 212 | pressed / active accent |
| `arkherGlow` | `#78BEFF` | 120, 190, 255 | titles, focus ring |
| `aurora` | `#50DC8C` | 80, 220, 140 | success, healthy budget |
| `amber` | `#F0C85A` | 240, 200, 90 | warning, degraded budget |
| `ember` | `#F06E6E` | 240, 110, 110 | danger, blown budget |
| `violet` | `#A98BFF` | 169, 139, 255 | Singularity AI surfaces |
| `teal` | `#4FD6D6` | 79, 214, 214 | D-O15 surfaces |

The two "family" colours matter: anything the **AI** did is violet, anything **D-O15** did is
teal. You can tell at a glance who changed your scene.

## 2. Roles

UI code never names a token — it names a *role*, so a theme swap can never break a screen:

```
background · backdrop · surface · surfaceAlt · track · border
text · textStrong · textMuted
accent · accentDeep · focus
success · warning · danger
ai · optimizer
```

## 3. Variants

| Variant | Purpose |
|---|---|
| `arkher-dark` | default; the cockpit theme above |
| `arkher-light` | daylight / documentation / print |
| `arkher-contrast` | maximum legibility (pure black, white borders) |
| `arkher-daltonic` | deuteranopia/protanopia safe — status is carried by **blue / amber / magenta**, never red-vs-green |

**All four pass WCAG AA** on every text-on-surface pair used in the product. This is not a claim,
it is a test: `Theme.audit(name)` computes real WCAG 2.1 relative luminance and contrast ratios
and returns the failures. Body text on panel measures **12.76:1**.

## 4. Metrics (mobile first)

Base unit `4`, radius `8`/`14`, gutter `12`, gap `8`. Type ladder: `11 / 13 / 15 / 18 / 24`.

Touch targets never go below **44 px** — the smallest reliably tappable target on a phone.
`Theme.metricsFor(device)` scales everything from the D-O15 device record:

| Tier | Scale | Touch target | Body font |
|---|---:|---:|---:|
| mobile | 1.15 (×1.05 under 700 px wide) | **50 px** | 17 |
| tablet | 1.08 | 47 px | 16 |
| desktop | 1.00 | 28 px | 15 |
| console | 1.35 | 59 px | 20 |
| VR | 1.50 | 66 px | 23 |

## 5. Semantic helpers

- `Theme.qualityColor(q)` — one place decides what "quality 0.62" looks like (green ≥ 0.7,
  amber ≥ 0.4, red below). The HUD bar and the profiler cannot disagree.
- `Theme.statusColor(status)` — `ok/degraded/failed/offline/ai/optimizing`.
- `Theme.categoryColor(key)` — deterministic colour for any string (system categories, graph
  edges, profiler lanes), golden-ratio rotated so neighbours stay distinguishable.
- `Theme.ramp(stops, n)` — gradient ramps for heat maps and budget bars.
- `Theme.readable(bg)` — picks the foreground with the better measured contrast.

## 6. Where it is applied today

- `roblox/hud.client.lua` — the in-game engine HUD (backdrop `void`, title `arkherGlow`, body
  `slate200`, quality bar `aurora`/`amber`/`ember`).
- `roblox/plugin.server.lua` — the ARKHER Studio adapter surface (`abyss` background,
  `slate900` panels, `arkherBlue` accent, `slate400` muted rows).
- ARKHER Studio's own `widget` kit carries the theme name through its render pass, so a theme
  change repaints only dirty nodes.
