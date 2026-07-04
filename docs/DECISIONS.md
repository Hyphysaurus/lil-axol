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

## D-0009 — Swim allows deep hover (Subnautica mobility) (2026-07-03, Mario)
The buoyancy spring no longer always floats the axolotl to the surface. It holds you near the
surface (top ~27px: `rest_depth` + `surface_band` 22) then **fades to neutral hover** with
depth, so idle underwater you keep your depth AND your aim instead of drifting up. Fixes the
"can't aim, keeps bringing me up" feel now that spray/bubble need free positioning. Supersedes
the always-surface half of D-0003; the frozen speed/hop/spray numbers are otherwise unchanged.
`surface_band` is a new AxolotlTuning export (higher = pulled up from deeper). Verified: buoyancy
target = 0 below 27px depth, pulls up near the surface. Feel-confirm in a desktop playtest.

## D-0010 — Sweetie 16 is the master palette (2026-07-03, Mario)
Every procedural / generated visual draws from the **Sweetie 16** palette (GrafxKid), held in ONE
place per side: `shaders/sweetie16.gdshaderinc` (const `SW_*` vec3s + `sw_petrol()` / `sw_fire()`
ramps, `#include`d by the shaders) and `game/palette.gd` (`class_name Palette`, the same 16 as
`Color` consts for GDScript particles/tints/UI). Applied this pass: the burning title now blazes on
the `sw_fire` ramp (rose→coral→gold→foam); the oil slick's full-spectrum HSV rainbow is replaced by
`sw_petrol` (an on-palette petrol shimmer through the cool tones) in `oil.gdshader` +
`oil_surface.gdshader`; fish/kelp/bubbles/sparkles/spray/dash/drip tints all point at `Palette.*`.
Edit a colour in the two source files and everything updates. Bug fixed alongside: the leak
barrel's `StaticBody2D` is now freed on burst, so the axolotl no longer stands on an invisible box
where the barrel was. Verified: 4.7 import + GL boot compile clean (no shader/script errors);
shipped to lilaxol.vercel.app. Feel/eyeball-confirm the sheen + fire intensity on the live build.
