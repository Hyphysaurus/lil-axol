# LilAxol — Build Status

**Updated:** 2026-07-22 (verified against code + git through `d657de2`; slice-4/5 stack live).
**Engine:** Godot 4.7 (GL Compatibility), exports via the Steam build + no-threads web template.
**Game:** *Lil Axolotl: Tidekeeper — The Living Watershed.* A cozy 2D pixel platformer/swimmer where
an axolotl restores its only real home — the Xochimilco canal wetlands — one reach at a time. The
reward is the living watershed returning underneath you. Design of record:
`docs/superpowers/specs/2026-07-07-living-watershed-master-design.md` (v2). Decisions: `DECISIONS.md`
(current through **D-0017**).

## The pivot in one line (D-0011)

The single `cleanliness` float is now a **system of ecological variables** (purity/toxicity, oxygen,
clarity, invasive ratio, vegetation) moved by **partner verbs**, with wildlife returning by **habitat
recipe** and a **multi-condition win**. `cleanliness` survives as the purity proxy + a derived legacy
read. Roster order: **Turtle → Frog → Dragonfly → Otter → Bat**.

## Reaches & topology (3 live)

| Reach | id | Geometry | Friend | Vars in play | Role |
|---|---|---|---|---|---|
| Hub | `hub` (`main.tscn`) | rect | — | purity | persistent home shell |
| Estuary / Reed Marsh | `estuary` | rect | Frog (kind 1) | purity, oxygen | frog rescue + oxygen recipe |
| The Canals | `canals` | **map-ingested** (2 PNGs) | Turtle (kind 0) | purity | **the game's first level** (D-0014); leak live; **east portal dormant** (reach 2) |

Travel loop wired: **hub ⇄ estuary ⇄ canals**. Reach 2 blocks on Maram's painted map
(`assets/maps/reach_template.png` is the blank; canals' east door wakes when it lands).

## BUILT — restoration systems (verified in code)

- **Reach-state engine** (`reach_state.gd`, group `reach_state`) — derives 5 vars (`purity` from the oil
  manager, `oxygen` = 1 − live grabbables/(debris+pest), `clarity` capped by live invasives, `invasive`,
  `vegetation` time-integrated). `blend_health` weights over the config's `in_play` set only.
  `recipe_met()` reads `win_recipe`; `&purity` is special-cased to `win_threshold` (single source of
  truth). **Backslide is legible:** vegetation grows over ~20s while its gate holds and **regresses at
  0.25× when the gate fails** (2Hz authoritative recompute). *(D-0011)*
- **ReachField oracle** (`reach_field.gd`, `class_name ReachField`) — the water/footing truth for both
  RECT reaches (`setup_rect`) and MASK reaches (`set_mask`). `is_water`/`oil_allowed`/`surface_y`/
  `floor_y_at`/`carve` etc.; cell codes AIR/EARTH/RUBBLE/WATER/CLIMB/SILT/BOULDER. Gives legacy rect
  reaches parity with painted ones.
- **Reach-map PNG ingester** (`reach_map.gd`) — two painted PNGs (terrain + markers, 1px = one 8px cell)
  → a playable reach. Terrain colors → earth/rubble/water/climb/silt/boulder; marker colors →
  spawn/friend/portal/leak/barrel/curio/lilypad/vent. `build()` lays the land quad (z7), greedy-merged
  collision, breakables (rubble free / silt+boulder locked, seals persisted `seal_<n>`), climbs, portals
  (persisted `portal_<edge>`, echo-guarded), vent caps, spawn. **Only `canals_a.tres` uses it today.**
  A new reach = a painting session. *(D-0014)*
- **CoveConfig contract** (`cove_config.gd`, `class_name CoveConfig`) — one `.tres` per reach: identity,
  water geometry, oil, ecosystem counts, **restoration group** (`in_play`, `win_recipe`,
  `vegetation_gate`), friend, environment tints, audio layers, leak, win threshold, two exits, and the
  **painted-map** block (`map_terrain`/`map_markers`/`map_exits`). Runtime fields ReachMap fills
  (`has_map`, `spawn_pos`, `pad_xs`, `barrel_positions`, `vent_positions`, `portal_markers`, …).

## BUILT — companions & verbs (verified in code)

- **Companion rig** (`companion.gd`, `class_name`-driven, group `sprayable`/`companion`) —
  `Kind { TURTLE, FROG, OTTER, DRAGONFLY }`; states SLEEPING→WAKING→FOLLOWING. `setup(cfg)` = the
  scene's rescuable sleeper; `setup_traveller(cfg,kind,slot,at)` = an already-rescued party member
  arriving awake, dressed from `CompanionLibrary`, slotted, roster-included; `wake_instant()` for the
  persistence spawn. `woke` signal → WorldState files `friend_awake`.
- **The Kirby rule (active-partner gating)** — static `verb_for(kind, Settings.run_active)` returns a
  verb only for the active traveller, so the single shared partner button fires **only** the current
  companion's verb, on PRESS. Turtle = shell-spin (full pilot state machine: carve, stamina, dizzy,
  hitstop, impact). *(D-0015)*
- **Dragonfly SURVEY** (built; rescue pending reach 2) — press → 1.8s spiral sweep (radius 180) → 6s
  reveal → bioindicator finish: hovers 2.5s at the **worst-oxygen point**, computed as a density pass
  (`densest_point`, radius 90) over group `grabbable` positions (fallback leak, fallback none). 10s
  cooldown. *(D-0016)*
- **Reveal contract** — `call_group("surveyable", "reveal", 6.0)`. Live opt-ins: `curio` (glint through
  terrain at z8, **unfound only**), `leak_source` (drip pulse + motes), `debris_field` /
  `invasive_school` (brightened silhouettes). ⚠ **`destructible_rock.reveal()` exists but is UNWIRED**
  (never joins `surveyable`, never called) → locked gates/rubble do **not** respond to Survey yet. See
  Loose Ends. *(D-0016)*
- **Scout hand-off** (`scout_dragonfly.gd`) — the wild pointing scout retires the instant a dragonfly
  enters the roster (`roster_changed` listener + restored/roster guards on setup). Fully wired.
- **Companion library** (`companion_library.gd`) — all four kinds registered with frames/anims/scale
  (turtle 40px, frog 50px, otter 32px, dragonfly 32px; 8 `.tres` present). **Otter is art-registered
  only — Herd/Haul/Build verbs land with slice 6.**
- **Partner HUD** (`partner_hud.gd`, layer 92) — chip row from `run_roster`, tap-to-swap, gold ring on
  active; per-chip **4Hz** cooldown arc polling `survey_hud_charge()`. As specced.

## BUILT — player, world, arcade layer (verified in code)

- **Axolotl** (`axolotl.gd`) — land walk/run/jump, swim/dive/buoyancy (deep-hover per D-0009), spray
  (aimed), surface hop, climb zones, **Bubble Bomb** (`bubble.gd`), Clean Wake **Dash**, Sit & Watch,
  and the **vent updraft** ride (physics here; vent state in `thermal_vent.gd`). Tuning in
  `axolotl_tuning.tres`; swim numbers frozen (D-0003).
- **Thermal vents** (`thermal_vent.gd`, `class_name ThermalVent`) — **restoration installs traversal**:
  clearing a vent's rubble cap opens it (plume/glow/surge + `geyser` feat); an open vent gives the
  axolotl an updraft. Not a hazard, not a barrel-blast trigger. *(D-0017; supersedes the explosion spec)*
- **Leak source** (`leak_source.gd`) — red barrel trickles oil (hard-capped in `oil_spill.gd`, D-0005);
  ~2s sustained close spray caps it, bursts, clears radius 60, fires `spring_clean`, **spawns a
  reclaim_token**.
- **Barrel economy — banking half only** (`reclaim_token.gd`) — a purified barrel drops a token → touch
  banks `+1 material` (echo-guarded) + HUD tally. **No spend/build consumer yet** — the Build side lands
  with the otter (slice 6). *(D-0013)*
- **Metroidvania terrain (slice 5)** — carve/seal actually lives in `destructible_rock.gd`
  (blast/carve/cleared, `locked` gates) + `reach_field.carve` + `reach_map._build_breakables` (persisted
  `seal_<n>`); secret pockets = `land_nook.gd` (turtle-only breakable loam). *(Note: `block_land.gd` and
  `climb_wall.gd` are healing-visual / climb-zone dressing, NOT the carve system.)*
- **Shine / Flow arcade layer** (`shine.gd`, group `shine`) — score/combo/Flow economy; `feat(name, at)`
  drives feat banner + echo ripples. Feats wired: `wake_up`, `first_survey`, `spring_clean`, `geyser`,
  `curio`. Post-win Tide Board (`high_scores.gd`) + shared Supabase leaderboard (`leaderboard.gd`).
- **Field Guide** (`field_guide.gd`) — card table (hub/estuary + encounter cards `enc_estuary_school`,
  `enc_dragonfly_rescue`); curio collection + proximity/rescue triggers show cards. *(Conservation hook,
  master §8.)*
- **Title** (`title_card.gd`) — **Continue / New Tide** split off `WorldState.has_progress()`; New Tide
  (two-tap arm→confirm) wipes the save + resets roster/score. Settings/credits present.
- **Atmosphere & payoff** — procedural sky + `day_night.gd` (120s, D-0008), reactive `seabed_backdrop`,
  `cove_life` kelp/fish fade-in, `shore_health`/`shore_pollution`, localized reveal + caustics,
  `restoration_banner` win handoff, `cleanup_fx`.
- **Palette** (`palette.gd` + `shaders/sweetie16.gdshaderinc`) — Sweetie-16 master, single-source (D-0010).
- **Audio** — `Sfx` autoload verb board + `cove_audio.gd` three-layer soundscape (ambience/life/music,
  music earned ~85%); buses persisted via `Settings`.

## PERSISTENCE (WorldState) — what's actually saved

`world.save` (ConfigFile, IndexedDB on web), `SAVE_VERSION = 1`, section-per-cove. **Corrupt / future
version → quarantine to `.bad`, start fresh, never crash.** Milestone-cadence writes. Persisted keys:
per-cove `restored`, `portal_cleared`, `friend_awake`, `cleanliness`, `curio_<i>`, `enc_school`,
`material`, `seal_<n>`, `portal_<edge>`, `tut_cascade`; global `cove_meta/first_survey`. **Roster is
derived** (rebuilt from `friend_awake` marks, not stored). **Echo runs** = session flag (score replay of
a restored reach; state untouched).

⚠ **Full reach-variable persistence is designed (master §7) but NOT built** — only `cleanliness`/purity
persists; oxygen/clarity/invasive/vegetation **re-derive live** from entity counts on load. Adequate
while reaches respawn to config, but the "save the exact ecological state" promise is unmet.

## DESIGNED, NOT BUILT

- **Slice 3 — full-pixel 640×360 art unification** (master §5) — **SKIPPED so far.** Master §10 orders it
  *before* new biomes; slices 4 & 5 shipped without it, so canals + estuary are authored against a grid
  we may re-author. See **P-6** in DECISIONS.
- **Otter + creek + the refugio + BUILD** (slice 6) — the spend side of the barrel economy (§3.6), carp
  Herd, refugio/weirs, Clarity payoff. Otter art registered; verbs unbuilt.
- **Bat + spring-grotto** (slice 7) — Echosong reveal, dark-biome lighting.
- **Recoverable-stakes fail vectors** (D-0012, master §3.7) — backslide is *partly* live (vegetation
  regress + capped re-oil); dead-end/material-stall as authored fail states are unbuilt. **D-0012 also
  awaits Bible ratification.**
- **Reach 2** — the dragonfly's home; blocks all of slice-4 Task 4 (unlock/portal/travel).

## KNOWN GAPS / LOOSE ENDS

- ⚠ **`destructible_rock.reveal()` is dead code** — Survey can't reveal locked gates/rubble until the
  rock joins group `surveyable` (or the sweep calls it). One-ish line, but it's a real reveal-contract
  hole; flagged for a ruling (does revealing sealed gates through terrain fit the cozy contract?).
- **MetSys is autoloaded but unused** — pushes `Map data file does not exist` on every boot and also
  errors the web export's map-data step (harmless: no map data ships). Wire it or drop the autoload.
- **Root still squatted** — `example/`, `scenes/`, `scripts/` are an unused RPG inventory/itemization
  pack (the export preset already excludes `scenes/*`/`scripts/*`; `third_party/` tidied the rest).
- **Merged branches** `feat/win-state-and-hygiene`, `refactor/cove-modular-architecture` undeleted.
- Pre-watershed gotchas from the old STATUS (orphaned `shaders/oil.gdshader`, unreferenced
  `newoilset.png`/`waterpack.png`, ~144/145 props unused) are **unre-verified this pass** — treat as
  stale until checked.

## SHIPPED / DEPLOYED

- **Live web build:** https://lilaxol.vercel.app (Vercel project `lilaxol`, static export from
  `build/lilaxol/`, no-threads template). **Re-deployed 2026-07-22** with the full slice-4/5 stack
  (Survey verb, dragonfly hand-off, reach-map canals, deep-hover, Sweetie-16). CDN serving byte-exact to
  the local export (`index.pck` 37,991,616 B verified).
- **Shared Tide Board** — Supabase table `lilaxol_scores` (public read, sanity-checked insert). Anon key
  ships by design; friendly-competition grade.

## AWAITING MARAM (playtest / eyeball)

- **P-5** seabed tile style-match — now on the live build, ready for the phone eyeball.
- **P-6** slice-3 do-now-or-defer (rule before reach 2 lands).
- Slice-4 **Survey feel** + **D-0009/D-0010** feel-confirms — all now deployed.
- **D-0012** Bible ratification (recoverable stakes).
