# LilAxol — Decision Log (ADR)

## D-0001 — Paint-to-clean replaces per-blob oil (2026-07-01, commit `62b2ae1`)
Cleaning is a coverage **mask** you erode with the spray (paint-to-clean), rendered by
`oil_surface.gdshader`; the old per-blob `oil.gdshader` system is retired. Fixed the
"tacked-on / no reward" feedback: cleaning now literally reveals the world.

## D-0002 — CoveConfig Resource + DI composition root (2026-07-01, spec: cove-modular-architecture)
One `CoveConfig` `.tres` per cove holds geometry + gameplay tuning; `cove.gd` injects it
one-way into components (children never `get_parent()`). Shader **colors stay authored in
scene materials** — YAGNI on config-driving art. Canonical numbers: the axolotl's
(water −142..457, surface −27, seabed 166).

## D-0003 — Swim-safety contract (2026-07-01, spec: cove-modular-architecture)
Swim behavior constants are **frozen** (WALK 90 / RUN 150 / JUMP −300 / GRAVITY 760, hysteresis
+4/−2, buoyancy/bob tuning, SPRAY_REACH 40 / RADIUS 36). Refactors may change where numbers
come from, never the numbers or the call sites. Swim was tuned by feel; treat it as shipped.

## D-0004 — Keep procedural sky; art budget goes to the seabed (2026-07-01, spec: atmosphere-backdrop, built `b6197aa`)
Sprite skies can't match the smooth day/night blend, so the procedural sky stays. Real pixel
art goes where shaders are weakest and the payoff is highest: the **reactive seabed backdrop**
the player uncovers by cleaning. Build deviations (accepted): no parallax band, per-tile
modulate jitter replaced by `seabed.gdshader` edge crossfade, improved procedural clouds
instead of sprite clouds.

## D-0005 — Leak is gentle pressure (2026-07-02, Mario)
The Layer-2 leak slowly re-oils a small radius until capped (hard-capped: coverage never
exceeds the level's start — oil resists, it never wins). Capping is a soft objective, not
a gate: ignoring it just keeps the spill lively longer.

## D-0006 — Sludge is skill (2026-07-02, Mario)
Thick sludge near the source needs SUSTAINED close-range spray to break (a held beam that
"bites in"), not just repeat passes. Tune so it reads as technique, never as a wall.

## PENDING (awaiting Mario's ruling)

- **P-3 Oil swim debuff** — built unspec'd (`OIL_DRAG` 0.5 max slow, swim-only): keep & record,
  soften (~25%), or remove. Intersects the "never punishment" pillar.
- **P-4 Next spec priority** — game-loop/post-win vs audio vs straight to implementation.
  Both specs are now DRAFTED as proposals (game-loop "A New Day", audio "Hear the Cove Come
  Back") — the remaining call is which to approve/build first. Recommendation: game-loop
  Phase 1 (closes the void, ~1 day), then audio Phase 1 (verbs make sound, ~1 day).
- **P-5 Seabed tile style match** — do the `water_clean_*` tiles cohere with the axolotl's
  pixel style now that they're live? Implicitly testable in-game, never recorded as decided.
