# The Rescued Friend — companion design

**Date:** 2026-07-02
**Status:** BUILDING — Mario asked for assets to unlock gameplay / a secondary character.
**Context:** The kindness beat ("Soothe the Oiled Animal") as a shipping feature today,
using art we already own: a second axolotl tinted wild-type olive. The rig is fully
data-driven (SpriteFrames + CharacterAnimSet + tint exports), so a purchased Lil Otter /
Frogpack later becomes a new companion with a resource swap and zero code.

## The beat
An oil-matted friend sleeps in the far deep corner of the cove (config `friend_pos`),
dark and still. Spray them CLOSE and SUSTAINED (~2.5s cumulative — the D-0006 skill verb)
and the oil washes off: their color lifts, they blink awake, chirp, award +500 Shine, and
follow you for the rest of the day. New Day resets the rescue — finding them again is
part of each morning.

## While following
- Lag-follow with a gentle bob; swim/swim_idle clips by speed, flip by direction.
- If you walk onto the beach, the friend waits at the water's edge (swim_idle) — axolotls
  belong in water; it also reads as "waiting for you", which is the point.
- **They help**: every few seconds, if there's film above them, they scrub a small patch
  (through the same `spray_at` path, so sparkles/Shine flow normally — small radius, a
  helper not a replacement).

## Architecture
- `game/companion/companion.gd` — one Node2D, code-built sprite, states
  SLEEPING → WAKING → FOLLOWING. Exports: `frames`, `anims` (CharacterAnimSet),
  `clean_tint`, `oiled_tint`. Injected `setup(cfg)`; reads `friend_enabled`, `friend_pos`.
- **"sprayable" group**: the axolotl's spray now also calls
  `get_tree().call_group("sprayable", "spray_at", reach, radius, delta)` — a generic
  spray-the-world hook (the ideation's Sprayable reactivity, arriving via this feature).
  The companion implements `spray_at` to accumulate rescue progress.
- `Shine.bonus(points, at)` — small public API for one-off awards (rescues, discoveries).
- Axolotl joins group "player" (companion follows the first member).

## Out of scope (recorded for the packs)
Otter/frog/crane companions (resource swaps once purchased), multiple simultaneous
friends, companion on-land waddling, crane-predator + Bubble Shield guardianship (own spec).
