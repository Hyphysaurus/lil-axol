# Aimed Spray · Shine Points · Bubble Bomb — Design (approved forks)

**Date:** 2026-07-02
**Status:** BUILT (2026-07-02) — verified by headless end-to-end sim + real-renderer boot.
Sim-tuned during build: pop radius 90→64 / strength 0.8→0.6 (was carving 31.6% of the cove;
now 15.5%), and charge gain is capped per scrub event (CHARGE_EVENT_CAP 60) — an untuned pop
refunded 2.12 bubbles (infinite chain), now 0.04. Combo pacing needs a feel playtest.
**Context:** One arcade loop, themed to restoration: aim the spray → scrub → earn **Shine**
(points + combo) → the combo chain charges the **Bubble Bomb** → a big AOE carve → more
Shine. Bubble is the bible's next Hydro Pack tool; Shield is deferred until something
exists to shield against (bosses / wildlife escort).

## A. Move-direction spray aim
While spraying, aim = input direction (stick analog / keys 8-way); neutral = facing.
The spray particles, reach point, and clean circle all follow the aim vector. No new
bindings; identical on keyboard / pad / touch. On land, up/down aim works because move_up
is unused on land and sit only triggers when *not* spraying. Facing is untouched by pure
vertical aim.

## B. Shine (points + combo)
- **Source:** `oil_spill.gd` emits a new `scrubbed(frac, world_pos)` signal whenever
  coverage actually comes off (frac = removed / total, so a full clean is a fixed base).
- **`game/cove/shine.gd`** (Node in cove.tscn, group "shine"): score = frac × 10,000 ×
  combo multiplier. Combo builds while scrubbing is sustained (+1 tier per 0.8s, max ×4)
  and gently drops back to ×1 after ~1.5s without scrubbing (no penalty, just decay —
  cozy-safe). Milestone chimes award +250 × milestone. Signals: `score_changed`,
  `charge_changed`, `bubble_ready`.
- **Floating pops:** small "+N" world-space labels at the scrub spot (throttled ~0.4s),
  drifting up and fading. Sparkle-white; combo tiers warm the color.
- **HUD:** `game/hud/shine_hud.gd` (top-right, under the banner's corner-sun spot):
  rolling score ticker, combo badge (×2/×3/×4), bubble charge icon that fills and pulses
  when ready. Hidden under UI lock.
- **Banner tally:** "Cove Restored" shows the final Shine (banner reads the "shine" group).
- Session-only score in v1; multi-cove totals + spend (cosmetics) recorded as future work.

## C. Bubble Bomb (Hydro Pack: Bubble)
- **Charge:** 1,200 Shine fills one bubble (one slot). Cleaning is the only way to charge —
  the loop feeds itself.
- **Input:** new `bubble` action (V key / pad Y / touch button). Fired while swimming: a big
  wobbling bubble (code-drawn) drifts along the aim (or facing) at ~90 px/s with gentle
  lift; after ~1.1s or on nearing the surface it **POPS**: one strong `spray_at` AOE
  (radius ~90, near-full-clear strength), burst + ring FX, milestone-chime *pop*, splash.
  Firing uncharged = soft deny blip. Land-fired bubbles are deferred (v1 water-only).
- **Never punishment:** no cost beyond the charge, no self-damage, no timer.

## Touched
`axolotl.gd` (aim + bubble fire), `axolotl_tuning.gd` (aim nothing / bubble numbers),
`game/axolotl/bubble.gd` (new), `oil_spill.gd` (scrubbed signal), `game/cove/shine.gd`
(new), `game/hud/shine_hud.gd` (new), `restoration_banner.gd` (tally line),
`touch_controls.gd` (bubble button), `cove.tscn`, `project.godot` (`bubble` action).

## Out of scope
Bubble Shield, mouse aim, persistent score/leaderboards, spending Shine.

## Post-build amendments (2026-07-02, Mario)
- **Land bubble built** (was deferred): blown on shore it drifts along the aim, settles,
  and pops the moment it kisses the water surface — right on the film.
- **Land/air dash built**: same verb as the wake dash, minus cleaning — a traversal scoot
  for the shore puzzles Mario is planning. Dashing off a ledge into water continues as a
  wake dash.
- **Cleanliness is now visibility-weighted + float-exact** (fixes "stuck at 81%"):
  progress counts only renderable oil (the film shader's ~0.28 knee), sub-visible residue
  snaps clean, coverage math moved off the 8-bit Image (truncation was silently leaking
  ~4% of credit), and win_threshold relaxed to 0.98. Sim: full scrub now reads 1.0000.
- **Axolotl.ttf** (Asset Library) is the project-wide theme font — ⚠ license unverified,
  see assets/fonts/SOURCES.txt.
