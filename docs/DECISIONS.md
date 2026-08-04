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

- **D-0012 Bible ratification** — the "cozy WITH recoverable stakes" re-ruling (world can fail,
  player cannot) needs the Lil Series Bible updated to match, plus confirmation it doesn't leak
  into the sibling games' identities. Recorded as ruled *direction*; awaiting explicit Bible sign-off.
- **P-6 Slice 3 (640×360 art unification) — do-now-or-defer.** Master §10 orders art unification
  BEFORE new biomes ("so they're authored native-pixel"); slices 4 & 5 shipped without it, so
  canals + estuary are authored against a grid we may re-author. Rule before reach 2 lands.
- **P-5 Seabed tile style match** — do the `water_clean_*` tiles cohere with the axolotl's
  pixel style now that they're live? **Deferred by Mario (2026-07-02):** ruling parked until
  he eyeballs the live build (lilaxol.vercel.app) from his phone; then record keep-vs-rework.
  *(Now re-deployed 2026-07-22 with the full slice-4/5 stack — ready for the phone eyeball.)*
- *(P-3 resolved → D-0007. P-4 resolved: game-loop Phase 1 + audio Phases 1–3 shipped. P-6 resolved →
  D-0018: ruled do-now — the 320×180 pixel shell shipped this slice.)*

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

## D-0011 — The Living Watershed pivot: one honest Xochimilco watershed + Terra Nil variable/recipe restoration (2026-07-07, Mario — master design v2)
The game re-frames from "cozy cove-cleaner" to **the true story of the axolotl's only home**: one
spring-fed Valley-of-Mexico watershed (Xochimilco), every reach ecologically real and laddering back
to axolotl habitat. Master spec: `docs/superpowers/specs/2026-07-07-living-watershed-master-design.md`
(**supersedes** the v1 `2026-07-06-hub-pond-living-world-design.md`; hub/persistence/Echo/frog/marsh
carry forward). The single `cleanliness` float becomes a **system of tracked ecological variables**
(Toxicity, Oxygen, Clarity, Invasive ratio, Vegetation — all 0..1, authored per-reach in `CoveConfig`,
persisted in `WorldState`), moved by **partner verbs** (spray/bomb → Toxicity ↓; turtle Break, frog
Consume → Oxygen ↑; dragonfly Survey reads; otter Herd → Clarity ↑ / Haul-Build; bat Echosong).
Wildlife returns by **habitat recipe** (variable thresholds), not by %. The win is a **multi-condition
recipe** (axolotl eggs need Toxicity ≤.15 AND Clarity ≥.75 AND Invasive ≤.2 AND eelgrass), never a
single-meter finish. `cleanliness` survives as a *derived read* for legacy consumers during migration.
Roster + unlock order fixed: **Turtle → Frog → Dragonfly → Otter → Bat**. Sliced (§10): 1 Foundations,
2 Restoration engine, 3 Art unification, 4 Dragonfly, 5 Metroidvania terrain, 6 Otter+Build, 7 Bat.

## D-0012 — Cozy WITH recoverable stakes: the world can fail, the player cannot (2026-07-07, master §1/§3.7) — ⚠ PENDING BIBLE RATIFICATION
Pillar 1 re-ruling. **No player death, no game-over, no punishment of the player** (the D-0007
never-punishment line HOLDS). But the **no-consequence** framing is lifted: reaches can **backslide**
(ignored spills spread, invasives multiply, oxygen falls — extends the capped pest re-oil, D-0005),
**dead-end** (started-but-stuck until you return with the missing partner/verb/material — the
metroidvania teased-lock made consequential), or **material-stall** (mis-spend cleaned material; reaches
are authored with sufficient material + a regenerating leak trickle so you can **never permanently
soft-lock**). All setbacks persist like wins; all are recoverable. **⚠ Master §12 flags this as needing
a Lil Series Bible update + confirmation it doesn't leak into the sibling games' identities — recorded
here, awaiting Mario's explicit ratification.** Permanent ecological loss (real local extinction) stays
a parked opt-in "stakes mode," NOT the default.

## D-0013 — Pollution becomes build material; the explosion-mechanics direction is superseded (2026-07-07, master §3.6/§12)
Cleaned pollution is **repurposed, not deleted** — the reverse-city-builder resource loop and the
design's strongest statement: *you build the healing out of the waste you removed.* Barrel lifecycle:
**empty → dilute → clean (spray) → becomes build MATERIAL** (a small per-reach currency); the otter's
**Haul/Build** verb seats cleaned material into build sockets to raise persistent structures (mesh
refugio / weirs / reed frames / nest platforms). This **supersedes both** the 2026-07-05 "barrels
purify/dissolve" behavior AND the 2026-07-03 explosion-mechanics-direction spec
(`docs/superpowers/specs/2026-07-03-explosion-mechanics-direction.md` → marked SUPERSEDED). The old
dissolve VFX can become the "reclaim" VFX. **Build state:** the material/build economy lands with the
otter (slice 6, unbuilt); today's `reclaim_token`/barrel behavior is the pre-economy seam.

## D-0014 — Reach-map PNG ingester is the authoring pipeline; Canals is the game's first level (2026-07-11, Mario — slice 5, RULED §9)
A reach is authored as **two painted PNGs** (terrain + markers, 1px = one 8px cell), ingested by
`game/cove/reach_map.gd` into the existing cove architecture. **A new reach costs a painting session,
not a scene-building session.** Rulings: (1) Maram's `marsh_draft` map ships as **"the Canals" — the
game's FIRST level**, where the turtle's rescue now happens (friend at open water); (2) the dormant
**east portal** ships drawn-dark, no trigger (wakes when reach 2 lands); (3) **broken seals STAY broken**
(`WorldState seal_<i>`, echo-run exempt). Legacy rect-geometry reaches (hub, estuary) keep parity via the
`ReachField` oracle (slice 5 foundation). Spec:
`docs/superpowers/specs/2026-07-11-slice5-reach-map-ingester.md`.

## D-0015 — The Kirby rule: the active partner gates the shared verb button (2026-07-14, slice 4)
There is **one** partner-action button (the turtle's original shell input); which verb it fires is keyed
to **who travels with you** — the trigger gates on `Settings.run_active == _kind`. Retrofitted onto the
turtle's existing pilot trigger (previously gated on instance kind only, so every rescued verb-bearer
answered at once — a real bug this fixes) AND applied to the dragonfly's Survey. Because only the active
partner ever listens, **verbs fire on PRESS** — zero latency, shell-identical feel; the earlier
"HOLD-vs-TAP disambiguation" policy is **deleted**. Commit `289c35f`.

## D-0016 — Survey reveal contract: one group call, each component owns its look, reveals are free (2026-07-14, slice 4)
The dragonfly's Survey makes the invisible visible via **one group call**:
`get_tree().call_group("surveyable", "reveal", 6.0)`. Components opt in and each owns its own look —
`curio` (glint through terrain, **unfound only**), `destructible_rock` (locked-gate glow), `leak_source`
(drip pulse + mote trail), `debris_field` / `invasive_school` (brightened silhouettes). Reveals render at
**z 8** (portal/FX plane, above the land quad's z 7), **duration-bounded**. **Survey has no cost** —
knowledge is free (conservation hook: observing IS the first restoration verb). The bioindicator finish
(hover at worst-oxygen point) is **new work, not a lookup**: a density pass over group "grabbable"
members' positions, fallback leak, fallback none. Tuning watch: a free 10s reveal-everything may flatten
seek-and-find pacing (playtest lever = 20s cooldown or bubble-charge link). Commits `c33e287`, `289c35f`.

## D-0017 — Thermal vents are restoration-installed updraft traversal, not barrel-blast triggers (2026-07-13, commit `7bdcf36`)
The explosion-direction spec floated vents as *barrel-cooking blast triggers* (D-0013 supersedes that
whole spec). What actually shipped is a cozier, traversal-first read: **restoration INSTALLS traversal** —
a healed reach's `thermal_vent` provides an **updraft** the axolotl rides, so cleaning the world literally
opens new vertical routes (the bible's "restoration unlocks traversal," ecology-native, never a hazard).
Confirm exact trigger/geometry against `game/cove/thermal_vent.gd`.

## D-0018 — Full-pixel base grid is 320×180, integer + expand, dithered Apollo bands (2026-07-23, Maram — slice 3, amends master §5)
The master spec's 640×360 would have zoomed the framing OUT ~1.5× (today's zoom-3 camera shows a
~427×240 world window); Maram ruled **320×180** (×4 → 720p, ×6 → 1080p) — characters read ~33%
BIGGER, the Animal Well / Celeste grid. Companion rulings: (1) **HUD/text stays native-res**
(master §5 letter — no pixel-font re-theme); (2) fill policy = **integer + expand** — biggest
integer scale that fits the physical window, viewport extends to fill, no letterbox, matching the
game's existing `expand` behavior; (3) color = **dithered Apollo bands** — one global post pass
(`shaders/apollo_post.gdshader`, Bayer 4×4, tunable `dither_strength`, a tuned constant not a user
setting) runs last inside the world viewport so even day/night Mood tints land on-palette.
Architecture: a **runtime pixel shell** (`game/fx/pixel_shell.gd`, built by `cove.gd` at `_ready`)
— scene files stay flat, wrappers untouched, world coordinates contract-identical (locked by
`tests/test_pixel_contract.gd`). Spec:
`docs/superpowers/specs/2026-07-23-slice3-full-pixel-unification-design.md`.
**Addendum (2026-07-24, Maram live-eyeball rulings):** (1) the palette snap runs BELOW PostFX
(quantized grain/vignette read as screen-wide noise — reverses the spec's "snap runs last");
dither gains a flat-zone deadband + a world-anchored Bayer weave, strength 0.2. (2) "Size is
fine, texture feels crude" → the shell's **effect grid is 640×360 with the camera at ×2**:
framing and art-pixel size on screen stay byte-identical to the 320×180 shell, while shaders,
particles, and dither render at double resolution. Art pixels stay integer (1 art px = 2
viewport px). The strict one-grid purism is deliberately traded for a finer atmosphere.
**(3, later the same day)** The snap ships **OFF** (`SNAP_ENABLED = false` in pixel_shell —
A/B screenshots proved the nearest-swatch mapping desaturates/red-shifts the whole scene; the
shader + dither stack stay mounted for a future palette dial). And the REAL "too muted" culprit
fell out of the hunt: `reach_map._draw_surround` had filled the ENTIRE map rect with near-ink
since slice 5, hiding the sky/sun/clouds in every map reach ("permanent midnight") — fixed to
its own doc-stated intent (margin slabs + underwater backdrop only; the air above the waterline
now shows the day/night sky). The sky pipeline itself was never broken.

## D-0019 — Rescues never steal the active-partner slot (2026-07-24, autonomous character-polish run — Maram pre-authorized "do it all headlessly")
`Settings.roster_add` claims `run_active` only when it is `-1` (no partner yet) — a NEW rescue
joins the roster but the partner you were using keeps answering the shared verb button. Resolves
the open slice-4 final-review ruling ("rescuing the estuary frog silences the turtle's shell
until a chip swap") along exactly the review's proposed softening lever; `roster_add` and
`roster_include` now share one polite semantics, so persistence/Echo paths are untouched by
construction. Companion UX shipped alongside: the **RescueCard** ceremony ("<Name> the <Species>
joins you!" + verb teach, non-blocking, layer 94, one-record data from `CompanionLibrary.INFO` —
names Tola/Meno/Nutria/Zuni), a 3s **chip glint** on newly joined partners, a one-time swap-teach
hint at roster size 2, and follow presence (facing-mirrored formation, staggered idle beats,
face-the-tidekeeper, tweened wake pop). Lint suite `tests/test_companion_library.gd` guards the
records + the no-steal contract. Spec:
`docs/superpowers/specs/2026-07-24-character-setups-polish-design.md`.

## D-0020 — Cleared chokes and purified barrels persist; restoration work is never undone by walking away (2026-07-26, Maram)
A pre-slice-6 audit found a **player-visible bug nobody had logged**: `debris_field.setup()` and
`shore_pollution._spawn_barrels()` respawned their full config count on **every** non-restored
visit. A five-second portal hop therefore undid the frog's tongue work — and because oxygen is 30%
of the estuary blend and its win recipe needs `oxygen >= 0.9` (≤1 of 11 chokes alive), the meter
visibly dropped and the win **re-locked**. The same defect let `material` and the `spring_clean`
feat be farmed by re-entering a reach.
**Ruled a BUG, not D-0012 backslide.** D-0012 sanctions reaches drifting backward, but 100%
instant regression on a scene crossing reads as *lost work*, not as a living world; backslide, if
it is ever authored, must be time-based and legible. Fix follows the shipped indexed-mark idiom
exactly (`curio_<i>`, `seal_<n>`): `floating_debris` gained `idx` + a `cleared(idx)` signal;
`debris_field` skips persisted indices and files an **echo-guarded** `debris_<i>`;
`shore_pollution` does the same with `barrel_<i>`. **No `SAVE_VERSION` bump and no WorldState
change** — new per-cove keys are additive, and a live save simply has none of them yet (fresh
profile → today's behavior). One subtlety locked by test: the placement draw happens **before** the
already-cleared skip, because `random_surface_x` advances the rng — skipping the draw would shift
every surviving clump's column on reload. Guarded by `tests/test_choke_persistence.gd` (13 checks).
**Ruled alongside:** the canals (the game's FIRST level) ships `invasive_count = 3` — master §3.5
wants the antagonist school visible early as the thing your current verbs pointedly cannot solve.
Purely a setup beat today: the canals' `in_play` is `[purity]`, so clarity/invasive still weigh
nothing in the meter or the win — they start counting when the otter's Herd lands (slice 6).

## D-0021 — The frog dives (2026-07-27, Maram — playtest ruling; amends master §9)
Master §9 shipped the frog **surface + land only, never dives**: `Kind.FROG`'s follow target carried a
hard `minf(target.y, surface_y - 2.0)` clamp. In play that reads as a partner *skating the ceiling*
while you swim away beneath it — Maram ruled it out at first sight. The clamp was also load-bearing in
the wrong way: it was **hiding deep-water follow jank rather than fixing it**, which is why removing it
required real work instead of deleting a line. The frog now still crosses water in ballistic hop arcs
and switches to the paddling swim only once your target is genuinely deep (`FROG_DIVE_DEPTH = 22px`
below the waterline), which doubles as the **hysteresis** that stops it flapping between hop and swim at
the boundary; an in-flight arc is **abandoned** on the switch rather than landed underwater. No new art
was needed — `swimforward`/`swimidle` were already authored in `frog_anims.tres` and had been
unreachable since slice 1. Master §9's bullet is annotated in place. The rest of §9 (integer
`friend_scale`, no runtime fractional scaling of pixel art, no perch AI) is untouched.

## D-0022 — On the 8px grid, an intended passage is THREE cells minimum (2026-07-27, arithmetic + two playtests)
Maram reported the same canals gap impassable **twice**. The first fix narrowed the axolotl's collider
16×18 → 14×18; the gap stayed shut. The arithmetic says why: the opening at map cells x=47..48, row 10
is exactly **two cells = 16px**, so a 14px body has **one pixel of clearance per side** — traversable in
theory, never in practice, at any tuning. The fix is authorial, not mechanical: two EARTH cells erased
at (46,9)/(46,10) in `marsh_draft_terrain.png`, eroding the platform's right edge by one column for a
three-cell / 24px shaft (~5px clearance per side). `test_reach_map`'s golden EARTH tally moves
2556 → 2554 with a note, since the map content changed on purpose.
**The rule for every painted reach from here: author any intended passage at three cells minimum.**
A two-cell opening will always *look* walkable and never be — the most expensive kind of level bug,
because it reads as a movement problem and pulls you into tuning the character. A one-cell notch is
decorative by definition and needs no clearance.

**ENFORCED 2026-07-28** by `tests/test_reach_geometry.gd`, and the route there is worth recording
because two more obvious designs failed first. **Connectivity cannot catch this class.** Flood-filling
the map twice — once with a point agent, once with a D-0022-sized body — and reporting what only the
point can reach came back **green against the pre-widening map**: the two-cell shaft was a *shortcut*,
not the only way through, so nothing was ever cut off. Maram's bug was never "I can't get there"; it
was "**this reads as a passage and isn't**" — a legibility defect, invisible to any reachability
measure. Conversely a purely local "flag every 2-cell opening" rule fires on scenery: its first run
flagged the open air under a one-cell pillar you simply walk around. Since intent is precisely what
geometry cannot infer, the shipped gate **names every constriction and fails on any not written down**
in an `ACCEPTED_TIGHT` allowlist, one documented line per exemption. Both connectivity checks were
kept anyway — they answer a different real question (content the player genuinely cannot reach) and
are green today.

## D-0023 — Verb access is never gated on a painting session: sandbox rect reaches carry finished verbs into play (2026-07-27)
D-0014 made the painted-PNG ingester the authoring pipeline and "a reach = a painting session." The
cost surfaced on 07-27: the **dragonfly's Survey verb has been fully built and tested since slice 4**
and was **unreachable in play** — no reach anywhere set `friend_kind = 3`, so Zuni could not be
rescued and the verb could never fire. A finished, tested mechanic sat dark for two slices waiting on
a painting session that also blocks reach 2.
**Ruled:** a verb ships in a **legacy-rect sandbox reach** rather than waiting for its painted home.
Two shipped: `creek.tscn` (Zuni, `friend_kind = 3` — Survey live the moment she's rescued, stocked
with debris/pests/a small invasive school so a sweep has something to reveal) and `refugio.tscn`
(Nutria, `friend_kind = 2`, `invasive_count = 6` — the school Herd will act on; her verbs land with
slice 6). Both reuse the hub's proven tank geometry (`seabed_y = 166`), which the same day's vent fix
now snaps to correctly. **The shipped progression is untouched** — canals ⇄ estuary ⇄ hub is
unchanged; the sandbox hangs off the hub's previously-unused second door (hub → creek ⇄ refugio → hub).
Painted reaches remain the real levels; a sandbox is a **proving ground**, not a substitute, and is
expected to be superseded when its painted reach lands. No curios authored in either — cards key off
`"<id>_<index>"` in `field_guide.gd` and would need writing first.
⚠ **OPEN — Maram's ruling:** both are live on the deployed build, so a player can meet Nutria, get the
full rescue ceremony, and receive a partner whose button does nothing until slice 6. Leave open, gate
the refugio door, or keep the spur dev-only?

## D-0024 — The map is memory: an auto-derived watershed chart, not an authored painting (2026-08-04)
Wayfinding's second half (the first was Batch C's door signage). The map overlay ("the watershed",
M / pad Select / rest-menu button) is **derived entirely from live data** — registry names + door
graph (`doors_of()`), door colours, `WorldState.visited/is_restored/current_id` — with zero
hand-authored map data: a new reach in the registry appears on the chart with no other edit.
**Ruled (Maram):** unvisited reaches adjacent to anywhere visited draw as a nameless, tintless,
edgeless "?" (a tease in the same grammar as the doors); anything further is absent. Sealed doors
draw like any open door — the rubble stays a surprise at the door itself. Layout is BFS-from-hub
over the FULL graph so the chart grows without rearranging. The rules live in `map_chart.gd`
(pure) under `tests/test_map_chart.gd`; the overlay only draws. This deliberately does NOT
preclude a hand-painted world map later (D-0014's register) — the chart is the honest data layer
a painting could skin.
