# LilAxol — Build Status

**Updated:** 2026-07-26 — **true-up pass** ahead of slice 6. A five-way verification audit against
the code (not the docs) preceded it and found three things the docs did not say: (1)
`tests/test_pixel_shell.gd` had been a **false green** since 07-24, printing `ALL PASS` on zero
executed checks; (2) cleared chokes and purified barrels **respawned on every reach crossing**,
undoing the frog's work and re-locking the estuary win — a live player-visible bug (**D-0020**);
(3) this file's own "orphaned `shaders/oil.gdshader`" claim was **wrong** — it is live, and acting
on it would have broken the build. All three are fixed. Hygiene shipped alongside: MetSys gone (all
three reaches now boot warning-free), root squatters gone, dead music gone, merged branches gone.
Suites: **14 files / 261 checks / all green**, and every RESULT line now reports its check count.

**Previously:** 2026-07-24 evening (verified against code + git through `0e08050`; slice-3 pixel shell
live + a full same-day polish arc: 640×360 desktop / 320×180 touch effect grids (framing identical,
`PixelShell.grid_zoom`), the canals SKY fix (slice-5 surround bug — map reaches were walled off from
their own sky since 07-12), Apollo snap parked OFF, V-tap bubble ride (free-glide + gold ring +
ride-lock + guide thread + Cascade chain aura), dive impact rings, pixel-fit clouds/stars, touch
sticky-aim + assist, Meno's kit (Active Tongue Snap + Springboard, D-0019 no-steal + Waking
ceremony + named characters), benthic floor dressing (field-aware, blooms with cleanliness),
estuary MudBed floater fix (wrapper-level node the shell couldn't capture), unlock-flow signposts
(post-restore "onward" nudge, dormant-door plum-seam tease), and a measured perf pass (HEAD 23%
faster than pre-slice-3 on the same restored save; PostFX defaults off on touch; sky fbm wisps cut).
Same-day detail lives in the commit log `e3cd3f4..0e08050` + the SDD ledger.
**Engine:** Godot 4.7 (GL Compatibility), exports via the Steam build + no-threads web template.
**Game:** *Lil Axolotl: Tidekeeper — The Living Watershed.* A cozy 2D pixel platformer/swimmer where
an axolotl restores its only real home — the Xochimilco canal wetlands — one reach at a time. The
reward is the living watershed returning underneath you. Design of record:
`docs/superpowers/specs/2026-07-07-living-watershed-master-design.md` (v2). Decisions: `DECISIONS.md`
(current through **D-0018**).

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
| The Canals | `canals` | **map-ingested** (2 PNGs) | Turtle (kind 0) | purity | **the game's first level** (D-0014); leak live; **east portal dormant** (reach 2); invasive school ×3 as an unsolvable setup beat (D-0020) |

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
- **Character setups polish (2026-07-24, D-0019)** — rescues never steal the active slot
  (`roster_add` claims only when none set); **RescueCard** ceremony toast on every live rescue
  (name/species/verb teach from `CompanionLibrary.INFO` — Tola/Meno/Nutria/Zuni — one record per
  character, otter/bat land by filling a row); new-partner chip glint + one-time swap-teach hint;
  follow presence (facing-mirrored formation, staggered idle beats, face-the-tidekeeper, tweened
  wake pop). Lint suite `test_companion_library.gd` (35 checks) guards records + the no-steal
  contract.
- **Headless suites: 14, 261 executed checks, all green** (recount 2026-07-26 — the old "14" was
  wrong twice over: there were 13 files, and one of them was a **false green**.
  `tests/test_pixel_shell.gd` printed `ALL PASS` while running **zero** checks from `0e08050`
  onward — its top-level `preload` of `pixel_shell.gd` stopped compiling the moment that commit
  added a `Settings` autoload read, so every `_test_*` aborted and `_fails` stayed 0. Converted to
  the `_process()` + lazy-`load()` idiom (now 16 checks incl. the touch grid). **Every suite's
  RESULT line now carries `(N checks)`** so an empty suite can never read as green again — gate on
  the count, not just the token.)
- **Field Guide** (`field_guide.gd`) — card table (hub/estuary + encounter cards `enc_estuary_school`,
  `enc_dragonfly_rescue`); curio collection + proximity/rescue triggers show cards. *(Conservation hook,
  master §8.)*
- **Title** (`title_card.gd`) — **Continue / New Tide** split off `WorldState.has_progress()`; New Tide
  (two-tap arm→confirm) wipes the save + resets roster/score. Settings/credits present.
- **Atmosphere & payoff** — procedural sky + `day_night.gd` (120s, D-0008), reactive `seabed_backdrop`,
  `cove_life` kelp/fish fade-in, `shore_health`/`shore_pollution`, localized reveal + caustics,
  `restoration_banner` win handoff, `cleanup_fx`.
- **Pixel shell (slice 3)** (`game/fx/pixel_shell.gd`, built by `cove.gd` at `_ready`) — reparents the
  world subtree into a runtime SubViewport shell: **640×360 effect grid, camera ×2** (D-0018 addendum —
  framing reads as 320×180 while shaders/dither render twice as fine; the apollo_post quantizer ships
  **disabled**, dial session pending; the slice-5 surround bug that hid the sky in map reaches is
  fixed — the canals finally shows its day/night sky), integer + expand scaled
  (no letterbox), camera ×1. HUD stays native-res. `shaders/apollo_post.gdshader` runs last inside the
  viewport (Bayer 4×4 dither, snaps to Apollo swatches). World-coordinate contract locked by
  `tests/test_pixel_contract.gd`. *(D-0018, amends master §5)*
- **Palette** (`palette.gd` + `shaders/apollo.gdshaderinc`) — Apollo master, single-source (D-0010,
  migrated 2026-07-04); slice 3 adds the global `apollo_post` quantizer.
- **Audio** — `Sfx` autoload verb board + `cove_audio.gd` three-layer soundscape (ambience/life/music,
  music earned ~85%); buses persisted via `Settings`.

## PERSISTENCE (WorldState) — what's actually saved

`world.save` (ConfigFile, IndexedDB on web), `SAVE_VERSION = 1`, section-per-cove. **Corrupt / future
version → quarantine to `.bad`, start fresh, never crash.** Milestone-cadence writes. Persisted keys:
per-cove `restored`, `portal_cleared`, `friend_awake`, `cleanliness`, `curio_<i>`, `enc_school`,
`material`, `seal_<n>`, `portal_<edge>`, `tut_cascade`, **`debris_<i>`, `barrel_<i>** (D-0020);
global `cove_meta/first_survey`. **Roster is derived** (rebuilt from `friend_awake` marks, not
stored). **Echo runs** = session flag (score replay of a restored reach; state untouched).

**Entity-level persistence closed 2026-07-26 (D-0020).** Cleared chokes and purified barrels used to
respawn on *every* reach crossing — a five-second portal hop undid the frog's work, dropped estuary
oxygen (30% of its blend) and re-locked its `oxygen >= 0.9` win recipe, and let `material` +
`spring_clean` be farmed by re-entry. Now filed with echo-guarded indexed marks in the `curio_<i>`
idiom; no `SAVE_VERSION` bump (additive keys). Guarded by `tests/test_choke_persistence.gd`.

⚠ **Full reach-*variable* persistence (master §7) remains NOT built** — oxygen/clarity/invasive
re-derive live from entity counts and vegetation resets to 0.0 on load. **Re-assessed 2026-07-26:
this is now a much smaller gap than it reads.** With D-0020 the entity counts the derivation reads
are themselves faithful, so oxygen reconstructs correctly; vegetation is in no reach's `in_play` or
`win_recipe` (its reset shows only as a dim pip, re-earned in ~20s); and clarity/invasive cannot be
moved by any shipped verb, so there is no information to lose until Herd lands. **Do not implement
§7 literally** — storing the numbers while entities still respawn to config would make the meter
contradict the visible water. Revisit as an entity-reconciled pass with slice 6.

## DESIGNED, NOT BUILT

- **Otter + creek + the refugio + BUILD** (slice 6) — the spend side of the barrel economy (§3.6), carp
  Herd, refugio/weirs, Clarity payoff. Otter art registered; verbs unbuilt.
- **Bat + spring-grotto** (slice 7) — Echosong reveal, dark-biome lighting.
- **Recoverable-stakes fail vectors** (D-0012, master §3.7) — backslide is *partly* live (vegetation
  regress + capped re-oil); dead-end/material-stall as authored fail states are unbuilt. **D-0012 also
  awaits Bible ratification.**
- **Reach 2** — the dragonfly's home; blocks all of slice-4 Task 4 (unlock/portal/travel).

## KNOWN GAPS / LOOSE ENDS

- ⚠ **`destructible_rock.reveal()` is dead code** — Survey can't reveal locked gates/rubble until the
  rock joins group `surveyable` (or the sweep calls it). **Verified 2026-07-26:** the cause is a plan
  defect, not a deferral — the slice-4 plan's Step 4 is the only one of five component steps that
  omits the `add_to_group("surveyable")` line, and commit `c33e287` reproduced the omission.
  `tests/test_reveal_contract.gd` calls `rock.reveal()` **directly**, and no test anywhere asserts
  group membership or fans out `call_group("surveyable", …)` — so the spec's own §6 fan-out test was
  never written either. **The ruling is currently moot:** zero locked gates exist in the shipped world
  (no SILT/BOULDER pixels in either map PNG) and Survey itself is unreachable (no reach sets
  `friend_kind = 3`), so this cannot be eyeballed until reach 2 lands. Only live question: do the 6
  LandNook loam mounds get revealed? They already shimmer idly, so it amplifies an existing tell.
- **Pre-watershed gotchas re-verified 2026-07-26** — ⚠ **`shaders/oil.gdshader` is NOT orphaned; it is
  LIVE** (`shore_pollution.gd:10`, `leak_source.gd:11`). The previous "orphaned" claim here was wrong
  and deleting on its advice would have broken the build. `newoilset.png`/`waterpack.png` **were**
  unreferenced → removed. Props: measured **143 of 149 unused** (not "~144/145"), but they are the
  authored art library for reaches 2-5 indexed by `assets/props/_catalog.json` — **do not bulk-delete**;
  the clean move is `.gdignore` + a small `props_live/`. Awaiting Maram's ruling.
- **Dead addons: `rmsmartshape` (14 MB), `lit`, `softbody2d` are all unused by game code** — none is
  referenced anywhere in `game/`. `lit` additionally owns the `LitManager` autoload and 15
  `[shader_globals]` entries no shader in `shaders/` reads (this supersedes the old "Lit shader globals
  track the window" bullet — Lit is not mis-wired, it is entirely unused). Removal is a clean win but
  was left out of the 07-26 pass to keep that pass verifiable; queued.
- **Repo carries 34 MB of never-used `third_party/rpg_icons`** — zero runtime cost (`.gdignore`d, 0 pck
  hits); purging needs a history rewrite, so deliberately left alone.

### Closed 2026-07-26 (true-up pass)

- ~~MetSys autoloaded but unused~~ — **removed**: autoload + both plugin entries out of
  `project.godot`, `MetSysSettings.tres` + `addons/MetroidvaniaSystem/` + the two `third_party/metsys_*`
  samples deleted. All three reach scenes now boot with **no MetSys warning** for the first time.
- ~~Root squatted~~ — **`example/`, `scenes/`, `scripts/` deleted** (136 tracked files, zero inbound
  references, already export-excluded; recoverable from git history).
- ~~Merged branches undeleted~~ — both deleted, local and origin.
- ~~18.8 MB of dead music shipping in the pck~~ — `gentle_breeze.ogg` /
  `wildflowers_by_the_river.ogg` removed (`cove_audio.gd` references only `mus_base`/`mus_alive`).
  Recoverable from git if a later reach wants them.

## SHIPPED / DEPLOYED

- **Live web build:** https://lilaxol.vercel.app (Vercel project `lilaxol`, static export from
  `build/lilaxol/`, no-threads template). **Re-deployed 2026-07-24** with slice 3 — the 320×180
  pixel shell + Apollo dither post-pass (D-0018) on top of the slice-4/5 stack (Survey verb,
  dragonfly hand-off, reach-map canals, deep-hover). Deployment `lilaxol-bn80eqvvl` verified
  target=production status=Ready; local `index.pck` 38,001,892 B.
- **Shared Tide Board** — Supabase table `lilaxol_scores` (public read, sanity-checked insert). Anon key
  ships by design; friendly-competition grade.

## AWAITING MARAM (playtest / eyeball)

- **P-5** seabed tile style-match — now on the live build, ready for the phone eyeball.
- *(P-6 resolved → D-0018: ruled do-now, this slice — the 320×180 pixel shell shipped.)*
- Slice-4 **Survey feel** + **D-0009/D-0010** feel-confirms — all now deployed.
- **D-0012** Bible ratification (recoverable stakes).
