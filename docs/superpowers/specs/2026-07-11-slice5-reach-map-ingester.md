# Slice 5 (foundation): The Reach-Map Ingester

**Date:** 2026-07-11 · **Status:** v2 — design-reviewed (6 Critical / 8 Important findings
incorporated); pending Maram's rulings (§9)
**Depends on:** Living Watershed master design §topology, the reach-map authoring kit
(522691e), Maram's first painted map (c1a9567).

## 1. Intent

Turn a painted reach map — two PNGs, 1px = one 8px cell — into a playable reach inside the
existing cove architecture. Pilot deliverable (RULED 2026-07-11): **Maram's `marsh_draft`
map ships as THE CANALS — the game's very first level**, where the turtle's rescue now
happens; restoration playable end-to-end on painted terrain. Once maps ingest, a new reach
costs a painting session, not a scene-building session.

## 2. Non-goals (v1)

- No hub/estuary migration (they stay hand-built; ingester retires when config has no map).
- One water table per reach; no secondary surfaces; no air pockets below the table (lint).
- No fluid sim (frozen). No otter/silt/boulder verbs (gates ship as teased locks).
- No in-game editor. No new art language (Apollo loam/water shaders evolve, not fork).
- No land pathfinding for companions (see 4.6 for the honest v1 behavior).

## 3. The authoring contract (shipped, now normative)

Files `assets/maps/<reach>_terrain.png` + `<reach>_markers.png`, same dimensions (pilot
120×60). `world = config.map_origin + cell * 8.0`. Exact legend colors; classification gates
on alpha ≥ 128 FIRST (import bleeds RGB into transparent pixels — reviewer M3), then exact
RGB match; load asserts the textures import lossless (compress mode 0).

Legend (terrain paints areas / markers are single pixels): earth `#7A4A23`,
rubble `#8C8C8C`, water `#2E6FF2`, climb `#2E9E3F`, silt gate `#D2B48C` (otter tease),
boulder gate `#56707E` (turtle+otter tease); markers spawn ×1 `#FF00FF`, friend ×0..1
`#FFD700`, portal ×1.. `#00FFFF` (at an edge = world connector), leak `#FF2222`,
barrel `#FF8800`, curio `#FFFF00`, lilypad `#B7F04A`, vent `#A020F0`.

Authoring rules the ingester relies on (lint enforces): borders are earth except portal-marked
tunnel mouths; rubble/gate components are rectangles; enclosed voids below the table are
water; **the friend marker sits in water or within 4 cells above it** (v1 companion rule,
reviewer C6 — land-roaming friends are slice 5.1).

## 4. Architecture

### 4.1 `game/cove/reach_map.gd` — loader + the ReachField service

A cove component injected like every other (`setup(cfg)`), **first in the injection list** so
config expansion happens before any consumer. When `cfg.map_terrain == null` → provides the
RECT-backed ReachField (below) from config numbers and builds nothing — hand-built reaches
run through the same service seam, so legacy behavior is preserved by construction.

With a map, at setup:
1. **Classify** both PNGs into a cell grid (alpha-gated exact match; off-legend →
   `push_warning` + air/ignored).
2. **Derive + expand config** (runtime only, never saved): `surface_y` (water-table row),
   water bbox (`water_left/right`, `seabed_y` = deepest water), `spawn_pos`, `friend_pos`,
   `curios`, `pad_xs`, barrel/leak/vent position arrays, `camera_bounds` (map rect + margin),
   `ground_hold_y`.
3. **Retire the hand-built cove** (reviewer C3 — this list is normative):
   `queue_free()` Beach, Seabed, Banks, BeachRight, BankTowerBody (collision), BlockLand,
   BlockLandRight, BankTower, Grass, GrassFront (visuals), TowerWall, TowerDrape (climb
   zones), LandNook1-3 (blastables), Vent1-3 (win-gate members!), GroundFill, SeabedBackdrop.
   The win gate polls group `thermal_vent` and requires ALL open — a hidden live hub vent
   makes a map reach unwinnable, so retirement is by `queue_free`, never `visible=false`.
4. **Build** (4.2–4.5) as children of this node; spawn map vents (thermal_vent instances at
   vent markers — they have no setup() and are not in the injection list, so ReachMap owns
   them; reviewer I6b).
5. **Report** one tally print (dev), mirroring the authoring auditor.

**ReachField API** (one service, two backings — rect for legacy, mask for maps; group
`"reach_field"`): `is_water(world) -> bool` · `surface_y()` · `water_bounds() -> Rect2` ·
`random_water_cell()` / `random_floor_cell()` / `random_surface_x()` (rejection-sampled
placement for spawners, reviewer I5) · `carve(world, radius)` (4.4).

Load budget: < 120ms web, one-time.

### 4.2 Terrain visual — one quad, the map IS the mask

`reach_land.gdshader` (evolves block_land's uniform set: `grid`, `surface_row` = table row,
`oil`, `env_tint`): full-map quad samples the terrain PNG nearest-filtered per cell — earth
and climb texels render the Apollo loam pattern (dry above the table, submerged band below),
everything else discards. **z_index = 7** (see z-map, 4.5). Env tint self-applied in setup
(the root's `_apply_environment` loop matches nodes by name and misses this quad — reviewer
M1; ReachMap also registers itself for the tint call).

Grass: a generalized `GrassLayer` that accepts per-cluster baselines (the legacy layer draws
from one y=0 baseline — reviewer M2): CPU-computed dry top edges (earth with air above, at or
above the table), ≤ 64 clusters, 18Hz throttle.

Bedrock surround: ReachMap draws its own GroundFill-style dark surround from the map rect
(the legacy node is freed). It doubles as the **backdrop behind translucent water** (water is
α 0.38/0.74 and needs dark behind it — reviewer I4): the surround fills the whole map rect
below the table at z 3, not just the outside.

### 4.3 Collision — greedy rect merge

Solid = earth + climb. Merge horizontal runs, then vertically → one StaticBody2D, ≤ 64
RectangleShape2Ds, legacy collision layer. Property test: rect union == solid set exactly.

### 4.4 Breakables and gates

- Each rubble rect component → one `DestructibleRock`: bounds-sized, **`edge = 1.5`**
  (default 0.92 erodes corners into an ellipse and leaves gaps in a 2-wide seal — reviewer
  I7; the portal plug already ships edge 1.25 for the same reason), slate/steel tones.
- Silt/boulder gates → `DestructibleRock` with new `locked := true`: `blast()` deals 0,
  plays a dull thunk + tone-colored shimmer (the world says *not yet*, never *no*). Tan pair
  / slate-blue pair. Slice 6 unlocks by kind.
- **Carved cells at/below the table become water** (reviewer C5): every rubble/gate rock
  reports cleared cells to `ReachField.carve()`, which flips them in the mask — otherwise the
  axolotl exits swim mid-tunnel after grinding through a seal. The legacy rect field made
  this true by construction; the mask must make it true explicitly.
- **Painted seals persist** (reviewer I6d): stable component ids (sorted by bounds), each
  fully-cleared seal marked in WorldState (`seal_<i>`), force-cleared (+ mask-carved) on
  revisit, skipped during Echo runs — otherwise every canals visit re-seals the west exit
  behind the player.

### 4.5 Water — backdrop rect + mask behavior + the z-map

**Visual:** the existing Water sprite/shader sized to the water bbox (top = table row).
Two shader rules pinned (reviewer I3): `rect_size` uniform must be set to the new size, and —
because the water ShaderMaterial is a shared sub-resource cached across cove instances (the
codebase already fought this leak for env_tint) — **rect_size joins the ALWAYS-write rule** in
`_apply_environment`: legacy reaches re-assert their 599×276 every setup. Verified safe:
waves/foam render only at the rect top edge, so sealed pockets grow no spurious surfaces.

**The z-map** (reviewer I4, normative): bedrock surround 3 · leak 4 · Water 5 · oil film +
pads + school 6 · **land quad 7** · portals/FX **8 on map reaches** (cove_portal ships z2 and
would vanish under the land quad; map-spawned instances get z 8) · companions 9 · axolotl 10.

**Behavior — every rectangle consumer moves to ReachField** (reviewer C1/C2/C6/I5; the seam
is only real if ALL of these consume it):
- **Axolotl**: lateral rect test → `is_water(feet)`; vertical hysteresis at the table
  unchanged (stay-in −2 / dip-in +4). D-0003 motion untouched — boundary query only.
- **OilSpill** (two Criticals): (a) it captures the Water rect in `_ready`, which runs before
  any setup — the rect read moves into `setup()`; (b) the coverage mask is built from a
  surface band with zero terrain knowledge — on marsh_draft it would be born inside the mesa,
  invisible behind the land quad, and block `purity ≥ 0.98` forever. Mask build zeroes
  non-water cells via ReachField; `_total`, `stain_at`, `set_clean_fraction` inherit.
- **Companions**: `over_water` (a bbox x-test that is true everywhere on a map and turns the
  ground-hold branch into dead code) → `is_water` column queries; follow-target footing
  clamps to the mask (a follower's target never sits inside earth); frog waterline ride and
  hop landings already key off `surface_y` (holds — one table). NEW **re-fan snap**: no
  far-snap exists today (verified); > 300px separation re-fans followers to the axolotl —
  cozy, no pathfinding.
- **Ambient spawners** (kelp/sprouts/crab at bbox seabed, fish/school bbox-clamped through
  walls, debris/pests across the surface band, reeds at bbox edges): placement moves to
  `random_floor_cell` / `random_water_cell` / `random_surface_x`; per-frame motion clamps
  stay bbox (cheap) — mis-swimming into a wall visual is acceptable v1 for fish, but
  *placement* inside earth is not.
- **Demolition clamps** (reviewer I2): shell pilot (`surface−125` ceiling, `water_right+64`)
  and bubble auto-pop (`surface−44`) clamp to `camera_bounds` on map reaches — the pilot map
  ships green today only because its rubble is low; the next map must not silently break.

### 4.6 Companions on painted maps

`ground_hold_y` derived (highest dry standable top − 4 cells) replaces the hub-tuned
GROUND_HOLD const via config (const stays as legacy fallback). Friend placement is
constrained by the authoring rule in §3 (in/near water, v1) — the pilot's mesa-crown friend
marker **must move** (ruling 4; the wake-follow lerp has no collision and would drag it
through the mesa into the water — reviewer C6). Land-roaming friends + follower pathfinding =
slice 5.1, explicitly out of scope.

### 4.7 Markers → components

- spawn → axolotl start (root repositions pre-first-frame).
- **Portal arrival** (reviewer C4): `_arrive()` hardcodes `(water_left+34, surface_y+46)` —
  on the pilot that is inside the west bank. Map reaches arrive at the ENTRY portal's marker:
  `Settings.arrive_via_portal` grows an `arrive_entry: String` (edge key) set by the
  crossing portal; the receiving root spawns at that portal's mouth, facing inward, still
  swimming. Legacy reaches keep the old two-number arrival.
- **Portals**: one `cove_portal` per marker; per-instance `exit_to` + NEW **dormant mode**
  (no destination configured: drawn dark, no trigger, no swirl — the honest teased door).
  `cove_portal` API grows `exit_to`/`entry_key`/`dormant`/`z_index` params; `_cross()` reads
  the instance, not the config singular. Persistence: `portal_cleared` keyed per entry
  (`portal_<key>`), wired for every instance (root currently wires only `$Portal`).
- leak/barrels/curios/lilypads/vents → explicit positions consumed by leak_source,
  **shore_pollution** (currently randomizes barrels at `water_left−226..` — off-map on a
  painted reach; gains explicit-positions mode — reviewer I6a), curio_field (already
  position-driven), lily_pads (`pad_xs`), and ReachMap-spawned thermal_vents.

### 4.8 The travel loop — canals FIRST (ruled 2026-07-11)

**The canals are the game's opening reach.** The project's main scene becomes `canals.tscn`;
a new game boots at the map's spawn marker (the west shallows, the whole reach readable to
the east — his composition already stages it).

- **Canals friend = the TURTLE** (`friend_kind = 0`), asleep at the friend marker (70,26) —
  open water at the mesa's west approach, matted in oil, visible on the first swim east. The
  first rescue and the shell-spin tutorial move here: the mesa's sealed passage and the
  bottom-channel seal are the turtle's first teaching walls.
- Travel chain: **canals ↔ estuary ↔ hub.** Canals west portal → estuary (once its seal is
  broken — the first level's exit is EARNED); canals east portal dormant (promise). The
  estuary's single `exit_*` is already spent on the return to the hub (reviewer I1), so
  hand-built `cove.tscn` gains an optional **$Portal2** + `exit2_*` config (retires when
  unset): estuary Portal2 (west bank) → canals. Hub unchanged. Shine carries across.
- **Accepted v1 wrinkle:** the hub still hosts its own hand-built sleeping turtle. With the
  turtle now rescued first in the canals, the hub's friend slot is fictionally stale —
  resolved when the hub migrates to a painted map (slice 5.1), where its friend beat gets
  redesigned. `roster_include` is idempotent, so nothing breaks mechanically; it just reads
  as a second turtle until then. Flagged, not hidden.
- Existing saves: WorldState is keyed per reach id; `canals` starts fresh for everyone,
  hub/estuary records untouched.

## 5. Config schema additions

```
@export var map_terrain: Texture2D           # null = hand-built reach
@export var map_markers: Texture2D
@export var map_origin := Vector2(-480, -200)
@export var map_exits: Dictionary = {}       # "west"/"east"/"top"/"bottom" -> scene path
@export var exit2_enabled := false           # hand-built second portal (estuary -> canals)
@export var exit2_target := ""
@export var exit2_pos := Vector2.ZERO
# runtime-expanded by ReachMap (never saved): spawn_pos, friend_pos, curios, pad_xs,
# barrel/leak/vent arrays, water bbox, surface_y, seabed_y, ground_hold_y, camera_bounds
```

Camera: `axolotl.setup()` applies `camera_bounds` as Camera2D limits when set (no consumer
exists today — reviewer I8; legacy configs leave it unset, camera unchanged).

## 6. Validation

- Authoring: `tools/audit_reach_map.ps1` (shipped).
- Load lint (dev): off-legend, non-rect seals, buried markers, portal-less edge water, air
  pockets below the table, VRAM-compressed import → `push_warning`, never crash.
- Headless `tests/test_reach_map.gd` (`RESULT: ALL PASS`): classification tallies vs known
  marsh_draft counts; derived config; rect-merge property test; marker harvest (1 spawn,
  2 portals, 15 lilypads, 3 curios); **rect-vs-mask ReachField parity on a synthetic
  rectangular map** (legacy-equivalence proof); carve() flips mask; locked-gate blast no-op;
  seal persistence round-trip; oil mask zero outside water; exit-edge resolution.
- Slice gate: world_state (11) + reach_state (12) suites green; parse gate clean; hub +
  estuary manual smoke — swim feel identical (D-0003 checklist); canals full loop playable
  on lilaxol.vercel.app.

## 7. Perf budget (web, GL Compatibility)

Land 1 quad + 1 mask texture · collision ≤ 64 rects (one-time) · ≤ 8 DestructibleRocks ·
≤ 12 climb strips @ 12Hz · grass ≤ 64 clusters @ 18Hz · water 1 quad · oil mask 192×88
(unchanged) · load < 120ms one-time · zero new per-frame full-map redraws.

## 8. Risks (post-review)

1. **Swim-feel regression (HIGH)** — ReachField seam + rect-backed legacy parity test +
   dedicated feel task. D-0003 numbers untouched.
2. **Oil/win correctness on masks (HIGH, was underestimated)** — oil mask zeroed outside
   water + setup-time rect capture; suite asserts coverage ⊆ water.
3. **Companion footing (MED)** — mask-clamped targets + friend authoring rule + re-fan snap;
   land pathing deferred to 5.1 loudly.
4. **Inherited hub nodes (MED, was underestimated)** — normative retire list (4.1.3); suite
   asserts no `thermal_vent` group members beyond map vents on a map reach.
5. **Shared-material leaks (MED)** — rect_size joins the always-write rule; parity smoke on
   hub after visiting canals.
6. **Scene-space/camera (LOW)** — camera_bounds consumer specified; demolition clamps follow.

## 9. Rulings — RESOLVED 2026-07-11

1. **Reach name: "Canals."**
2. **Canals friend: the TURTLE, and the canals are the game's FIRST LEVEL** (see 4.8; friend
   marker moved to open water at (70,26) by the punch-list patch).
3. **Dormant east portal**: ships as spec'd (drawn dark, no trigger) — dormant by default.
4. **Punch list: DONE via script** (patch committed): portal → (2,41) in tunnel water, 22
   stray marker-layer blues deleted, floater strips extended 2 cells (dangling roots →
   graspable), friend moved. Post-patch audit: zero off-legend, all markers legal, all
   climb strips graspable, no unreachable water.
5. **Seal persistence: broken seals STAY broken** (WorldState `seal_<i>`, echo-run exempt).

## 10. Task seeds (for the plan)

1. ReachField service (rect backing) + axolotl/companion/oil/spawner adoption on LEGACY
   reaches + parity suite — ships alone, zero visible change, de-risks everything.
2. reach_map loader: classify/derive/harvest/lint + retire list + headless suite.
3. Land visual (reach_land shader + generalized grass + bedrock-backdrop surround) + z-map.
4. Collision rect-merge + property test.
5. Breakables: seals (edge 1.5) + locked gates + carve() + seal persistence.
6. Marker wiring: spawn/arrival entry keys, multi-portal + dormant, shore_pollution &
   lily_pads & vents explicit modes, camera bounds, demolition clamp switch, re-fan snap.
7. canals_a.tres (turtle friend, first-level tuning) + main scene → canals + estuary
   Portal2 + travel loop + deploy gate. Punch-list fixes already landed (ruling 4).

Each task lands behind the parse gate + suites; the slice ships when the canals loop plays
on lilaxol.vercel.app with hub/estuary byte-identical.
