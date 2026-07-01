# Cleaning Depth & Feel — Design Proposal

**Date:** 2026-07-01
**Status:** PROPOSAL — for Mario's review (drafted while paint-to-clean is being playtested)
**Context:** Paint-to-clean fixed "tacked-on" + "no reward." This addresses the remaining
half of the feedback: *"cleaning is very simple and easy."* Goal is **engagement/texture,
not difficulty** — LilAxol is cozy; depth here means variety, a light objective, and a
world that responds, never punishment.

## Problem

With paint-to-clean, scrubbing is satisfying but still one-note: hold spray, sweep the
surface, done. There's no reason to aim thoughtfully, no arc to a cleanup, no verb besides
"spray," and the industrial oil-*source* is implied but never present. The ~120-sprite
industrial prop library (barrels, pipes, valves, scaffolds) is also still unused.

## Three additive layers (each independently shippable)

### Layer 1 — Oil variation (cheap, high impact)
Make the slick non-uniform so *where* you scrub matters:
- **Thickness ramps toward the source.** Oil is thin at the far (left) edge — one pass —
  and thick/clotted near the source (right). Natural gameplay arc: clear the easy edges,
  work inward toward the stubborn core. (Already half-true via the blotchy mask; make it
  intentional — bias initial coverage by `x` toward `spill_right`.)
- **Two visual states in one shader:** thin *sheen* (bright iridescence, clears instantly)
  vs thick *sludge* (dark, matte, needs sustained spray). Drive off the coverage value —
  `oil_surface.gdshader` already has the pieces (edge/rim iridescence); add a matte-dark
  core for high coverage. Reads richer, rewards sustained scrubbing on the dark bits.
- **Cost:** shader tweak + a one-line bias in `_build_mask`. No new systems.

### Layer 2 — Cap the leak (the headline: a verb + a use for the props)
Right now oil just *is* there. Give it a **source**: a leaking barrel/valve on the right
ledge (real industrial sprites → first real use of the prop library).
- The valve slowly trickles fresh coverage into the mask near the source until capped.
- **Cap it** with a hold-to-interact (reuse `spray`/`dash`, or a new `interact`): a small,
  satisfying "clunk," the drip stops, a light "leak sealed" beat.
- This creates a **soft objective + optimal order** (cap first, then clean) without a fail
  state — if you ignore it, the spill just stays lively a bit longer. Cozy-safe tension.
- **Cost:** one `LeakSource` component (sprite + trickle-into-mask + cap interaction),
  driven by CoveConfig (`leak_pos`, `leak_rate`, `leak_enabled`). Additive; off => today's
  behavior. Follows the DI pattern.

### Layer 3 — The world reveals as you clean (deepen the reward)
Tie recovery to incremental discovery, not just the global fade:
- **Fish return one at a time** at cleanliness thresholds (not all at 0→1) — CoveLife
  already spawns them; gate their individual reveal on `_clean` crossing per-fish thresholds.
- **God-rays / caustics strengthen** with cleanliness (water shader already has caustics;
  scale `caustic_strength` by `clean`).
- **Small delight moments:** scrubbing a patch can reveal a hidden critter (snail, starfish)
  or a bubbling seabed vent — a reason to clean *everywhere*, not just enough to win.
- **Cost:** low; mostly gating existing CoveLife spawns on thresholds.

## Recommended order
1. **Layer 1** (oil variation) — ship with paint-to-clean; it's a shader/init tweak.
2. **Layer 3** (incremental reveal) — cheap, big feel win, no new art.
3. **Layer 2** (cap the leak) — the meatiest; unlocks the prop library and a real objective.
   Do this once the art direction (procedural vs sprites) is settled, since the valve is a sprite.

## Open questions for Mario
- How much tension is "cozy"? (Leak = gentle pressure, or purely optional flavor?)
- Should thick sludge near the source need a *held* spray (skill) or just more passes (patience)?
- Is "cap the leak" the right first use of the industrial props, or save props for set-dressing?

## Out of scope
Audio (separate spec), backdrop art (separate spec), multi-cove progression.
