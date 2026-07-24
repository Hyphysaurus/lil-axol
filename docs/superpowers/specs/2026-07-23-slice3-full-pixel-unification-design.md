# Slice 3 — Full-Pixel Unification @ 320×180

**Date:** 2026-07-23 · **Status:** approved by Maram (brainstorm 2026-07-23)
**Amends:** master design §5 (`2026-07-07-living-watershed-master-design.md`) — base grid is
**320×180**, not 640×360. Record as **D-0018** in DECISIONS.md.

## Why

The world today renders at window resolution (1280×720, `canvas_items` stretch) with the camera at
zoom ×3: sprites are chunky but every fullscreen shader (sky, clouds, water, oil sheen, god-rays)
renders smooth at native res — the painterly-vs-pixel tension the asset map flagged. This slice puts
the whole world on ONE pixel grid with ONE palette (the Animal Well proof: Hollow Knight atmosphere
on a pure low-res grid), before any new biome is authored. Side effect: fullscreen shader cost drops
~9× — a real win for the no-threads web build on phones.

## Ratified decisions (brainstorm 2026-07-23)

1. **Base grid 320×180** (×4 → 720p, ×6 → 1080p). Characters read ~33% BIGGER on screen than
   today's zoom-3 framing (~427×240 visible). Chosen over the master spec's 640×360 (which would
   have zoomed OUT 1.5×) and over keeping today's non-integer framing.
2. **HUD/text stays native-res** (master §5 letter). No HUD re-theme; Field Guide prose, ES/EN
   text, and touch controls stay crisp.
3. **Fill policy: integer + expand view.** Biggest integer scale that fits, then the viewport
   extends a few world-pixels to fill the window — no letterbox bars, every pixel perfect. Wider
   screens see slightly more world (matches the game's existing `expand` aspect behavior).
4. **Color: dithered Apollo bands.** One global post pass snaps every world pixel to an Apollo
   swatch, with Bayer 4×4 dither between the two nearest swatches. `dither_strength` uniform
   (0 = flat bands), tuned as a constant — not a user setting.
5. **Architecture: SubViewport inside cove.tscn** (approach A) — chosen over project-wide
   `viewport` stretch (would pixelate the HUD) and over per-shader faux-pixel quantization at
   native res (no perf win, shimmer on odd devices, more total work).

## Architecture

`cove.tscn` restructures once; the three reach wrappers (`main.tscn`, `estuary.tscn`,
`canals.tscn`) are untouched.

```
Cove (Node2D root — cove.gd composition root, authored offset e.g. (509,172))
├─ WorldView (SubViewportContainer · top_level · full-window · stretch=true · pixel_shell.gd)
│   └─ World (SubViewport · nearest filter · snap_2d_transforms_to_pixel)
│       └─ WorldOffset (Node2D — takes Cove's final global transform at _ready)
│           └─ [world subtree: ReachMap, GroundFill, LilyPads, Reeds, Curios, ReachState,
│               InvasiveSchool, Axolotl (Camera zoom ×1), Beach/Seabed/Banks/BlockLand/…,
│               Water, OilSpill, CoveLife, SeabedBackdrop, DebrisField, PestField, Friend,
│               LeakSource, Vents, Portals, ShorePollution, ScoutDragonfly, FeatEcho,
│               SkyLayer, CloudLayer, Mood (CanvasModulate), TimeOfDay, PostFX,
│               ApolloSnap (new, topmost layer)]
└─ [root subtree — native res: RestorationBanner, NewDay, TouchControls, RestorationMeter,
    ShineHud, FeatBanner, PartnerHud, HighScores, Hints, PerfOverlay,
    Shine, CoveAudio, ShoreHealth (non-spatial logic)]
```

### pixel_shell.gd (on WorldView)

- On window resize: `scale = max(1, floor(min(win.w / 320.0, win.h / 180.0)))`;
  set `stretch_shrink = scale`. The container's built-in stretch then renders the SubViewport at
  `ceil(window / scale)` — integer + expand with zero letterbox code. Scale math lives in a pure
  static function (unit-testable headless; clamp ≥1 guards the windowless server viewport).
- At `_ready`: make WorldView `top_level` + full-rect (so the Cove root's Node2D offset can't
  shift the container on screen) and copy Cove's final global transform onto `WorldOffset`.

### The coordinate contract

World global coordinates inside the SubViewport are **identical to today's** — `WorldOffset`
reproduces exactly the transform the world subtree inherited from the Cove root (scene-authored ×
wrapper offset). Camera limits math in `axolotl.gd`, portal positions, reach-map cell origins,
marker harvests, and every WorldState key are untouched. Any diff in a world global position is a
bug in the shell, not a retune target.

### Camera & motion

- Axolotl `Camera2D` zoom (3,3) → (1,1). Visible world ≈ 320×180 (+expand remainder) vs today's
  ~427×240 — the ratified zoom-in.
- Project setting `rendering/2d/snap/snap_2d_transforms_to_pixel = true` so camera smoothing and
  the spring-juice sprite offsets (axolotl lean, turtle squash, fish waggle) quantize to the grid
  instead of shimmering. Springs stay — they just step in whole pixels now.

### Input

`SubViewportContainer` (stretch=true) auto-transforms mouse/touch into viewport coordinates —
aimed spray, drag-to-swim, and tap-to-command flow through unchanged. Verify on the phone build.
HUD Controls sit at root, outside the container, and receive native-res input as today.

## The Apollo post-pass (`shaders/apollo_post.gdshader` + ApolloSnap node)

- Fullscreen ColorRect on the **topmost CanvasLayer inside** the SubViewport, so it runs LAST:
  day/night Mood tints, god-rays, grain, and vignette all land on-palette.
- `#include "res://shaders/apollo.gdshaderinc"`; build the swatch array from the SW_* consts
  (the include is the single source of truth — no literals).
- Per pixel: sample `hint_screen_texture` (nearest), find the two nearest swatches by RGB
  distance, pick via Bayer 4×4 threshold × `dither_strength` (default subtle; 0 = hard
  posterize). Uniforms: `dither_strength`, `enabled` (debug A/B).
- Cost: 320×180 × small const loop — trivial on GL Compatibility, phones included. If the perf
  probe disagrees, fall back to a precomputed LUT texture (plan-level contingency, not expected).
- Sprites are already Apollo-authored, so the snap is a near-no-op for them by construction.

## Known fallout (in scope, handled)

- **Fullscreen ColorRects** (Sky, SunMoon, Clouds, Post): re-anchor to full-rect inside the
  viewport so they track ~320×180; shaders adapt via `SCREEN_PIXEL_SIZE`/`SCREEN_UV`. Audit each
  for hardcoded window-size assumptions.
- **Low-res feel pass** (in scope, bounded): dial existing uniforms (band counts, scroll speeds,
  octave trims, mote counts/sizes) so water/sky/clouds/particles read as composed pixel art at
  320×180 — not just shrunk. No shader rewrites beyond uniform/constant tuning.
- **`lit` addon**: `lit_viewport_size`/`lit_canvas_scale` shader globals must track the
  SubViewport IF Lit is actually in use — the plan's first task verifies whether LitManager drives
  anything live (suspected MetSys-style dead weight; if dead, note it, don't wire it).
- **DI path breaks → group lookups**: any `get_node("../Sibling")` crossing the new world/root
  boundary converts to group-based lookup (groups already carry most cross-talk: `shine`,
  `reach_state`, `restoration`, `sprayable`, `surveyable`). The five scripts STATUS flags as
  path-fragile (`oil_spill`, `cove_audio`, `day_night`, `seabed_backdrop`, `shore_health`) are the
  expected candidates. Paths that stay within one side keep working — reparenting preserves
  relative paths inside the moved subtree.
- **Physics/audio worlds**: all bodies/areas move together into the SubViewport, so they share
  one physics space regardless of whether the SubViewport allocates its own World2D — but the plan
  verifies no script OUTSIDE the viewport does a physics query, and that non-positional audio
  (Sfx verb board, CoveAudio layers) is unaffected.
- **Iris wipe** renders inside the viewport (pixel transitions, cohesive). **Title card** (burning
  text) is a root HUD layer — native-res, crisp, untouched.
- **PerfOverlay** stays native and readable.

## Testing

- **Headless (must stay green, unchanged):** WorldState round-trip suite, `test_reach_state`
  (12 checks), boot lint.
- **New headless unit test:** the pure scale/expand math across real device sizes —
  1280×720 → ×4, 0 expand · 1920×1080 → ×6 · 844×390 (phone) → ×2, viewport 422×195 ·
  639×359 → ×1 · degenerate 0×0 → clamp ×1.
- **New boot check:** after shell init, assert a known world node's global position equals its
  pre-slice value (the coordinate contract, executable).
- **Phone eyeball (Maram, post-deploy):** axolotl size feel · water/sky band + dither strength ·
  HUD crispness · touch aim + drag-to-swim · portal transition · FPS via PerfOverlay vs today.

## Rollout

- Hard cutover on `main` — no runtime toggle (the old look lives in git). `ApolloSnap.enabled`
  exists only as a debug uniform for A/B during tuning.
- Deploy to lilaxol.vercel.app after local + headless green; Maram phone-checks the list above.
- Docs wave: DECISIONS **D-0018** (320×180 amendment + fill policy + dither ruling) · STATUS
  update (also fix the stale "Sweetie-16 master" palette line — Apollo is master, the include is
  `apollo.gdshaderinc`) · edit-note in master §5 pointing here.

## Out of scope

- HUD re-theming / pixel font work (HUD stays native by decision 2).
- Reach re-authoring (coordinate contract makes maps untouched).
- Any gameplay/tuning change beyond the visual feel pass (swim numbers frozen per D-0003).
- Per-shader artistic rewrites; palette LUT optimization (contingency only).
- Hub migration to a painted map (slice 5.1) and everything slice 6+.
