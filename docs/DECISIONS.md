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

## D-0007 — Oil slows, never punishes (2026-07-02, Mario — resolves P-3)
The swim-in-oil debuff stays (the design bible sanctions "oil slows movement"), **softened
to 25% max slow** (`oil_drag` 0.5 → 0.25 in `axolotl_tuning.tres` + script default). Thick
oil should have weight you feel, not a wall you fight — the "never punishment" pillar wins the
magnitude call. Swim-only; land movement is untouched. ⚠ Data-only change; confirm the feel
in-editor next desktop session.

## D-0008 — Day length is 120s (2026-07-02, Mario)
The day/night cycle ships at **120 seconds** (the 20s debug value is retired). Long enough to
sit-and-watch a full cycle without it churning; this is the canonical value for cove #1.

## PENDING (awaiting Mario's ruling)

- **P-5 Seabed tile style match** — do the `water_clean_*` tiles cohere with the axolotl's
  pixel style now that they're live? **Deferred by Mario (2026-07-02):** ruling parked until
  he eyeballs the live build (lilaxol.vercel.app) from his phone; then record keep-vs-rework.
- *(P-3 resolved → D-0007. P-4 resolved: both specs drafted AND built — game-loop Phase 1 and
  audio Phases 1–3 shipped; no open priority call remains.)*
