# Explosion Mechanics — Design Direction (not yet built)

**Date:** 2026-07-03
**Status:** DIRECTION captured (Mario, 2026-07-03) — spec + build later.
**Context:** Mario added a Red Oil Barrel + a 12-frame Exploding Red Oil Barrel and wants
explosions to become a real mechanic: *"open rubbled pathways... clear large oil-slicked
areas... or something similar."* This turns the one-off barrel burst into a reusable tool.

## What's already built (the seed)
`game/cove/leak_source.gd` — spraying the red oil barrel neutralizes the source; it BURSTS
(the explosion sheet) and the blast **clears a radius of oil** (`spray_at`, BLAST_CLEAR 60).
So "explosion clears oil" already exists as a proof of concept, tied to the leak source.

## Where this goes (two uses Mario named)
1. **Clear large oil-slicked areas.** Explosions as a *cleanup power*: a blast wipes a big
   patch of the coverage mask at once (vs the sustained spray). Could be barrel chains (one
   barrel's blast detonates nearby barrels), or the existing **Bubble Bomb** could detonate a
   barrel for a bigger combined clear. Ties to the Shine/arcade loop (big blast = big Shine).
2. **Open rubbled / blocked pathways** (traversal gating — the bible's "unlock new
   traversal"). Needs a **destructible-obstacle system**: rubble/debris sprites with a
   `blast_at(pos, radius)` that removes them and opens a path (collision + visual). This is
   the exploration backbone for multi-cove (MetSys biome map) — blocked routes that open as
   you clear the pollution/obstacles.

## Design guardrails (cozy)
- Explosions **clear and open — never threaten the axolotl** (no damage/fail state). The
  blast is a tool, a reward, a key — not a hazard to the player.
- Reuse what exists: the `spray_at`/`stain_at` mask ops, the "sprayable" group, the Bubble
  Bomb, CleanupFX. A generic `blast_at(world_pos, radius)` on OilSpill (big instant clear) +
  a `Destructible` component (rubble that a blast removes) covers both uses.

## Trigger idea — THERMAL VENTS (Mario, 2026-07-03)
Blasts are triggered by **thermal vents**, not a hand-held bomb. Fits the world (the cove
already has seabed vents; the bible's Volcanic Springs biome is all thermal). Shapes:
- A vent periodically surges (heat/pressure builds — a visible tell, a rising shimmer); a
  red oil barrel sitting on/near a vent is **cooked until it bursts** on the surge. You
  position/roll a barrel onto a vent, or clear the path so the surge reaches it.
- Or the vent surge itself is the blast — time your presence/Bubble to channel it to clear a
  big oil patch or blow rubble. Cozy: the surge never hurts the axolotl, it's a timed tool.
- Ties cleanly to a `thermal_vent` component (CoveConfig-driven, like the leak) + `blast_at`.

## Open questions for the build spec
- What triggers a blast? Thermal vents (above) — vent-cooked barrels vs vent-as-blast?
  Also: Bubble Bomb → barrel chain? A dedicated verb, or purely environmental (vents)?
- Is rubble-clearing a single-cove feature or does it arrive with multi-cove exploration?
- Chain reactions (barrel → barrel) — yes/no?

## Out of scope (until spec'd)
The destructible/rubble system, chain reactions, any explosion that damages the player.
