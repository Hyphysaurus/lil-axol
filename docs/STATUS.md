# LilAxol — Build Status

**Updated:** 2026-08-04 — **Batch C of the polish pass shipped** (`ea8e820` + `9e72f71`, committed,
**not yet deployed**): the world has NAMES and doors tell you where they lead.
`game/world/reach_registry.gd` is the identity table (hub=**El Embarcadero**, estuary=**El Tular**,
canals=**Las Acequias**, creek=**El Arroyo**, refugio=**El Refugio** — Californio Spanish, Maram
2026-07-28), with the door graph *derived* from the .tres configs so wiring keeps one home. Portal
signage runs at two ranges: far = throat light + swirl motes take 45% of the destination's door
tint; near (90px) = "This way lies <Name>." via hints. Doors home glow too — hub and canals author
no `env_water_tint`, so the registry carries **signage-only door colours** for them (hub lantern
gold, canals flower-market lilac; Maram's 2026-08-04 ruling — shipped water untouched, tint values
await her eyeball on a deploy). `WorldState.visited` is live: the cove root stamps every non-echo
arrival (additive key, old saves self-heal from any cove section) — **the map overlay (Batch D) now
has its "been here" source.** Nutria's rescue card carries honest copy instead of silence (the
"teaches a nonexistent verb" loose end was a STALE ledger claim — grep-verified nothing ever taught
one; the real gap was the silent card before a dead chip). Gates: **19 suites / 459 checks all
green** — new suites `test_visited_wiring.gd` (arrival stamps; an echo run does NOT) and
`test_boot_gate.gd` (the "five reaches boot clean" gate promoted from a manual eyeball to a
save-safe suite that also asserts each root carries its own config). All new gates RED-proven.
Batch B (camera feel) still not started; Batch D (map overlay) is now unblocked.

**Previously:** 2026-07-28 (doc true-up; verified against code + git through `73ec50d`, all claims
below re-run, not copied) — covering the **2026-07-27 playtest-response day**, seven commits,
`4cbbd69..73ec50d`, all deployed. Maram played and filed reports; four of five were one root cause
deeper than they looked. **The estuary was unwinnable** — `cove.tscn` hardcodes thermal vents at
y=164 (the hub's seabed), but the estuary raises `seabed_y` to 96, sealing all three vent caps 68px
*inside* solid mud where no spray, bomb or shell could reach them; `restoration_banner` needs every
vent open, so the 97% ceiling was never the oil (**vents now take y from the reach config**; painted
reaches exempt, since ReachMap places those at their authored marker). **The travelling party died on
every page reload** — `Settings.run_roster` is memory-only and was refilled solely from the reach you
stood in, stranding every other rescued partner; the roster is now **derived from world memory**
(`WorldState.awake_friend_kinds`, `friend_kind` written beside `friend_awake`, old saves self-heal).
**Two portals were drawn inside cliffs** (estuary→hub and the hub's own plugged exit — the way out you
must break open was invisible). **The frog now dives** (D-0021, reverses master §9 at Maram's ruling)
and **the shell spin finally collides with terrain** — Companion has no physics body at all, so the
spin was `position += vel` fenced only by the reach rect and sailed through every hand-placed wall.
Plus: a real `swap_partner` binding (Q / left-stick — previously a 34px HUD chip was the *only* way to
swap), a full four-companion party that no longer stacks on one follow slot, rescued friends spawning
**beside you** instead of at their original rescue spot ~650px away, cloud coverage restored
(1.05 → 1.35), pest-flies halved, D-0020 extended to shore oil splats (`splat_<i>`), and the
canals shaft widened to three cells (**D-0022** — on the 8px grid a 2-cell opening is never
traversable, at any collider size). **Two new sandbox reaches shipped: `creek` (Zuni the dragonfly)
and `refugio` (Nutria the otter)** — D-0023, and the reason Survey is reachable in play at last.
Gates re-verified 2026-07-28: **all five reaches boot clean**, and the suite battery is now **15
files / 353 checks / all green** — the new one being **Batch A of the polish pass**,
`tests/test_reach_geometry.gd`, which turns "is anything buried or unreachable?" from a playtest
question into a gate (details under BUILT).

**Previously:** 2026-07-26 — **true-up pass** ahead of slice 6. A five-way verification audit against
the code (not the docs) preceded it and found three things the docs did not say: (1)
`tests/test_pixel_shell.gd` had been a **false green** since 07-24, printing `ALL PASS` on zero
executed checks; (2) cleared chokes and purified barrels **respawned on every reach crossing**,
undoing the frog's work and re-locking the estuary win — a live player-visible bug (**D-0020**);
(3) this file's own "orphaned `shaders/oil.gdshader`" claim was **wrong** — it is live, and acting
on it would have broken the build. All three are fixed. Hygiene shipped alongside: MetSys gone (all
three reaches now boot warning-free), root squatters gone, dead music gone, merged branches gone.

**Before that:** 2026-07-24 evening (verified against code + git through `0e08050`; slice-3 pixel shell
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
`docs/superpowers/specs/2026-07-07-living-watershed-master-design.md` (v2, **§9 amended by D-0021**).
Decisions: `DECISIONS.md` (current through **D-0023**).

## The pivot in one line (D-0011)

The single `cleanliness` float is now a **system of ecological variables** (purity/toxicity, oxygen,
clarity, invasive ratio, vegetation) moved by **partner verbs**, with wildlife returning by **habitat
recipe** and a **multi-condition win**. `cleanliness` survives as the purity proxy + a derived legacy
read. Roster order: **Turtle → Frog → Dragonfly → Otter → Bat**.

## Reaches & topology (5 live)

| Reach | id | Geometry | Friend | Vars in play | Role |
|---|---|---|---|---|---|
| Hub | `hub` (`main.tscn`) | rect, seabed 166 | — | purity | persistent home shell; **two doors** |
| Estuary / Reed Marsh | `estuary` | rect, seabed 96 | Frog (kind 1) | purity, oxygen | frog rescue + oxygen recipe. **Winnable again as of `4cbbd69`** — its three vents were sealed inside the mud floor |
| The Canals | `canals` | **map-ingested** (2 PNGs) | Turtle (kind 0) | purity | **the game's first level** (D-0014); leak live; **east portal dormant** (reach 2); invasive school ×3 as an unsolvable setup beat (D-0020) |
| The Creek | `creek` | rect, seabed 166 | **Dragonfly (kind 3)** | purity, oxygen | **sandbox** (D-0023). The only reach that sets `friend_kind = 3`, so **Survey — built and tested since slice 4 — is finally reachable in play**. Stocked with debris, pests, small invasive school |
| The Refugio | `refugio` | rect, seabed 166 | **Otter (kind 2)** | purity | **sandbox** (D-0023). Nutria joins and travels correctly today; her Herd/Haul/Build verbs land with slice 6. `invasive_count = 6` — the school Herd will act on |

**Wired topology (verified against the five `.tres` configs, 2026-07-28):**

```
        ┌──────────────── plug (turtle ram / bomb) ───────────────┐
        ▼                                                          │
    ESTUARY ══ exit2 ══▶ CANALS ══ west ══▶ ESTUARY            [HUB / main.tscn]
        ╚═════ exit ═══════════════════════════════════════════════╝
                                                                   │ exit2
                                                                   ▼
                            CREEK ══ exit2 ══▶ REFUGIO ══ exit ══▶ CREEK
                              ╚═══════ exit ═══════════════════════▶ HUB
```

- **Shipped progression:** hub ⇄ estuary ⇄ canals — unchanged by the 07-27 work.
- **Sandbox spur:** hub → creek ⇄ refugio → hub, hanging off the hub's previously-unused second door.
- **Canals' east edge is dormant** (its `map_exits` carries only `west`) — the reach-2 tease.
- ⚠ **Doors now tell the player where they lead (Batch C, 2026-08-04)** — far tint + near name via
  the reach registry — **but there is still no map or minimap.** MetSys (which would have provided
  the map layer) was removed as unused in the 07-26 hygiene pass; the replacement is Batch D's
  overlay, now unblocked by `WorldState.visited`.
- Reach 2 still blocks on Maram's painted map (`assets/maps/reach_template.png` is the blank;
  canals' east door wakes when it lands). The creek/refugio sandboxes deliberately **do not**
  (D-0023): they are legacy rect, so no painting session gates them.

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
  persistence spawn. `woke` signal → WorldState files `friend_awake` **+ `friend_kind`** (07-27).
- **The travelling party (fixed 2026-07-27)** — three separate defects, all player-visible:
  (a) the roster died on every page reload (memory-only, refilled from the local reach) → now derived
  from `WorldState.awake_friend_kinds()`; (b) at **full party size** `_spawn_travellers` always
  reserved follow slot 0 for the local friend *even when that friend wasn't with you*, so four
  travellers needed slots 1..4, `SLOT_OFFSETS` defines exactly four, and `clampi` silently stacked the
  last two on one offset → slot 0 is now reserved only when the local friend genuinely travels, and a
  roster larger than `SLOT_OFFSETS` pushes a warning naming the fix; (c) `wake_instant` restored an
  already-rescued friend's *state* but left it standing on `friend_pos`, re-materialising the frog
  ~650px down the estuary while every other party member spawned beside you → the local friend is now
  seated on its own slot 0 (measured: frog 2px from the axolotl in the estuary, turtle 5px in the
  canals). **Max party is 4** — `SLOT_OFFSETS.size()`. Verified with a full turtle/frog/otter/dragonfly
  party cold-loaded into all five reaches: 4/4 present, every one on a distinct slot.
- **Frog dive (D-0021, 2026-07-27)** — the follow target's hard `minf(target.y, surface_y - 2)` clamp is
  gone. The frog still crosses water in ballistic hop arcs and switches to the paddling swim only once
  your target is genuinely deep (`FROG_DIVE_DEPTH = 22px`, which doubles as the hysteresis that stops
  it flapping at the boundary); an in-flight arc is abandoned on the switch rather than landed
  underwater. The `swimforward`/`swimidle` anims it needed were already authored in `frog_anims.tres`
  and had simply been unreachable. **Reverses master §9's surface-only rule at Maram's ruling.**
- **The Kirby rule (active-partner gating)** — static `verb_for(kind, Settings.run_active)` returns a
  verb only for the active traveller, so the single shared partner button fires **only** the current
  companion's verb, on PRESS. Turtle = shell-spin (full pilot state machine: carve, stamina, dizzy,
  hitstop, impact). *(D-0015)*
- **Shell spin collides with terrain (fixed 2026-07-27)** — `Companion` extends `Node2D` and has **no
  physics body at all**: the spin was `position += vel * delta` fenced only by the reach's outer rect,
  so it sailed through banks, block-land and every hand-placed wall. It now probes the **physics
  space** (centre + one radius ahead, so a fast spin can't tunnel a thin wall between frames), slides
  along a wall it grazes and bounces off a head-on hit through the existing impact stack. Queried
  against physics rather than the `ReachField` mask **deliberately**: painted reaches keep terrain in
  both a mask and rect bodies, but the legacy hub/estuary keep theirs **only** in hand-placed
  `StaticBody2D`s the field knows nothing about — physics is the one source both share. Breakables are
  skipped on purpose (the 20Hz carve beat eats those; stopping on rubble would kill the tunnel fantasy
  and re-seal the portal plug the shell exists to smash). Regression checked: every breakable in all
  reaches still has 96/96 free approach points.
- **Dragonfly SURVEY** (built; **now reachable in play via the creek**, D-0023) — press → 1.8s spiral sweep (radius 180) → 6s
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
  active; per-chip **4Hz** cooldown arc polling `survey_hud_charge()`. As specced. **`swap_partner`
  (Q / left-stick click) added 2026-07-27** — cycles the roster in rescue order. Until then a 34px HUD
  chip was the *only* way to swap partners: no keyboard or gamepad binding existed at all.

## BUILT — player, world, arcade layer (verified in code)

- **Axolotl** (`axolotl.gd`) — land walk/run/jump, swim/dive/buoyancy (deep-hover per D-0009), spray
  (aimed), surface hop, climb zones, **Bubble Bomb** (`bubble.gd`), Clean Wake **Dash**, Sit & Watch,
  and the **vent updraft** ride (physics here; vent state in `thermal_vent.gd`). Tuning in
  `axolotl_tuning.tres`; swim numbers frozen (D-0003). **Collider narrowed 16×18 → 14×18
  (2026-07-27)** — at exactly 16px wide it had *zero* clearance in a 2-cell opening and always jammed;
  14px gives sub-cell clearance on the 8px grid. (Necessary but not sufficient — see D-0022.)
- **Thermal vents** (`thermal_vent.gd`, `class_name ThermalVent`) — **restoration installs traversal**:
  clearing a vent's rubble cap opens it (plume/glow/surge + `geyser` feat); an open vent gives the
  axolotl an updraft. Not a hazard, not a barrel-blast trigger. *(D-0017; supersedes the explosion spec)*
  **Vent y is config-driven as of 2026-07-27** (`thermal_vent.setup`, injected by group so a fourth
  vent needs no code edit). `cove.tscn` hardcoded y=164 — the hub's seabed — which put all three of the
  estuary's vents 68px *below* its own mud floor, sealed in solid ground. Since `restoration_banner`
  requires every vent open for full restoration, **the estuary could not be completed at all**; its 97%
  ceiling was the vents, not the oil. Painted reaches are exempt: ReachMap places vents at their
  authored marker, and overriding that dragged the canals' map vent off its painting (caught by
  `test_pixel_contract`'s vent-0 check, not by review).
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
- **Reach geometry gate** (`tests/test_reach_geometry.gd`, 2026-07-28, 92 checks) — the mechanical
  answer to the 07-27 playtest, where **both** headline bugs were the same shape: *a thing the player
  must reach, sitting inside solid geometry*, silently, in a **legacy rect** reach. Instantiates all
  five reaches and probes every vent, portal, friend, curio, leak and spawn against the **physics
  space** — the one terrain source painted and legacy reaches share (`ReachField`'s mask would miss
  the legacy reaches entirely, which is where both bugs were). Solidity ignores anything under
  `blastable`/`turtle_blastable`, mirroring `companion.gd:_shell_solid_at` exactly, because a vent
  under its own rubble cap is the design and a vent under the mud floor is the bug. Three probe kinds:
  centre-clear + approach ring for things you occupy, ring-only for fixtures embedded by design (the
  leak barrel), and **mouth-opens-upward** for vents — a vent's origin sits *on* the seabed plane by
  construction, so a centre test there is meaningless (the first draft of this suite reported all
  twelve legacy vents as buried, including the hub's, which have shipped for months). Part 2 enforces
  **D-0022**: every 2-cell constriction is named with coordinates, and any not on the documented
  `ACCEPTED_TIGHT` allowlist fails. **RED-proven both ways, not assumed:** reverting
  `thermal_vent.gd` to `4cbbd69^` fails exactly the three estuary vents (0/16 bearings free) and
  nothing else; restoring the pre-widening `marsh_draft_terrain.png` fails naming
  `vertical shaft 2 cells wide at x=47..48, row 10` — the shaft Maram reported twice.
- **Headless suites: 15, 353 executed checks, all green** (recount 2026-07-26 — the old "14" was
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
per-cove `restored`, `portal_cleared`, `friend_awake`, **`friend_kind`**, `cleanliness`, `curio_<i>`,
`enc_school`, `material`, `seal_<n>`, `portal_<edge>`, `tut_cascade`, **`debris_<i>`, `barrel_<i>`,
`splat_<i>`** (D-0020); global `cove_meta/first_survey`. **Roster is derived** (rebuilt from
`friend_awake`/`friend_kind` marks, not stored). **Echo runs** = session flag (score replay of a
restored reach; state untouched).

⚠ **Doc-drift note, kept as a warning:** this section claimed "roster is derived" *before it was
true* — until `4cbbd69` (2026-07-27) `Settings.run_roster` was memory-only and was refilled solely
from the friend of the reach you happened to be standing in, so one page reload stranded every other
rescued partner. The claim is accurate as of that commit. Same class of error as the "orphaned
oil.gdshader" and "13/13 green" entries: **audit against code before acting on anything here.**

**Entity-level persistence closed 2026-07-26 (D-0020).** Cleared chokes and purified barrels used to
respawn on *every* reach crossing — a five-second portal hop undid the frog's work, dropped estuary
oxygen (30% of its blend) and re-locked its `oxygen >= 0.9` win recipe, and let `material` +
`spring_clean` be farmed by re-entry. Now filed with echo-guarded indexed marks in the `curio_<i>`
idiom; no `SAVE_VERSION` bump (additive keys). Guarded by `tests/test_choke_persistence.gd`.
**Second wave 2026-07-27:** the first pass missed `shore_pollution`'s land oil splats, which alone
came back at full strength on every re-entry while debris and barrels stayed cleared — now
`splat_<i>`, same idiom, still no version bump.

⚠ **Full reach-*variable* persistence (master §7) remains NOT built** — oxygen/clarity/invasive
re-derive live from entity counts and vegetation resets to 0.0 on load. **Re-assessed 2026-07-26:
this is now a much smaller gap than it reads.** With D-0020 the entity counts the derivation reads
are themselves faithful, so oxygen reconstructs correctly; vegetation is in no reach's `in_play` or
`win_recipe` (its reset shows only as a dim pip, re-earned in ~20s); and clarity/invasive cannot be
moved by any shipped verb, so there is no information to lose until Herd lands. **Do not implement
§7 literally** — storing the numbers while entities still respawn to config would make the meter
contradict the visible water. Revisit as an entity-reconciled pass with slice 6.

## DESIGNED, NOT BUILT

- **Otter BUILD + Herd** (slice 6) — the spend side of the barrel economy (§3.6), carp Herd,
  refugio/weirs, Clarity payoff. Otter art registered and **Nutria now joins the party and travels
  correctly** (D-0023); her **verbs are still unbuilt**, so her chip currently answers the shared
  partner button with nothing. The *places* — `creek.tscn`, `refugio.tscn` — shipped 2026-07-27 as
  legacy-rect sandboxes; the **refugio mesh art remains a true asset gap** (master Appendix A.5).
- **Bat + spring-grotto** (slice 7) — Echosong reveal, dark-biome lighting.
- **Recoverable-stakes fail vectors** (D-0012, master §3.7) — backslide is *partly* live (vegetation
  regress + capped re-oil); dead-end/material-stall as authored fail states are unbuilt. **D-0012 also
  awaits Bible ratification.**
- **Reach 2** — the painted dragonfly reach; still blocks on a painting session (D-0014). **No longer
  blocks Survey**: the creek sandbox carries `friend_kind = 3`, so the verb is live in play (D-0023).

## KNOWN GAPS / LOOSE ENDS

- 🔴 **Wayfinding, remaining half (was: "none of any kind").** Batch C closed the door half
  (2026-08-04): every portal names its destination at 90px and glows its door tint from afar, and
  `WorldState.visited` records where you have been. **Still missing: the map overlay itself**
  (Batch D — the layer MetSys would have provided) and any at-a-glance answer to "how do these five
  reaches connect?". The registry's `doors_of()` already derives the full graph, so the overlay is
  a rendering task, not a data one.
- *(Closed 2026-07-28 — see `tests/test_reach_geometry.gd` under BUILT.)* ~~Painted-map traversal is
  not linted; nothing enforces D-0022.~~
- ⚠ **`destructible_rock.reveal()` is dead code** — Survey can't reveal locked gates/rubble until the
  rock joins group `surveyable` (or the sweep calls it). **Verified 2026-07-26:** the cause is a plan
  defect, not a deferral — the slice-4 plan's Step 4 is the only one of five component steps that
  omits the `add_to_group("surveyable")` line, and commit `c33e287` reproduced the omission.
  `tests/test_reveal_contract.gd` calls `rock.reveal()` **directly**, and no test anywhere asserts
  group membership or fans out `call_group("surveyable", …)` — so the spec's own §6 fan-out test was
  never written either. **Half-moot as of 2026-07-27:** Survey is now reachable in play (the creek
  sets `friend_kind = 3`, D-0023), but zero locked gates exist in the shipped world — no SILT/BOULDER
  pixels in either map PNG — so the missing group membership still has nothing to reveal and cannot be
  eyeballed until a reach paints one. Only live question: do the 6
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
  `build/lilaxol/`, no-threads template). **Re-deployed 2026-07-27** with the playtest-response day —
  estuary winnable, party persistence, unburied portals, frog dive, shell-spin collision, the two
  sandbox reaches. **Verified live 2026-07-28:** `index.html` md5 and `index.pck` byte length both
  match `build/lilaxol/` exactly (`index.pck` **15,528,544 B** — down from 38,001,892 B, the dead
  music + asset purge in the 07-26 hygiene pass).
- **Shared Tide Board** — Supabase table `lilaxol_scores` (public read, sanity-checked insert). Anon key
  ships by design; friendly-competition grade.

## AWAITING MARAM (playtest / eyeball)

- **P-5** seabed tile style-match — now on the live build, ready for the phone eyeball.
- *(P-6 resolved → D-0018: ruled do-now, this slice — the 320×180 pixel shell shipped.)*
- Slice-4 **Survey feel** + **D-0009/D-0010** feel-confirms — all now deployed, and Survey is
  finally *playable* (creek).
- **D-0012** Bible ratification (recoverable stakes).
- **New 2026-07-28 — are the sandbox reaches player-facing?** `creek` and `refugio` are live on the
  deployed build off the hub's second door. As shipped a player can wander into the refugio, meet
  Nutria with the full rescue ceremony, and receive a partner **whose button does nothing** (Herd/Haul
  land with slice 6); neither reach has curios or field-guide cards. Options: leave them open (honest
  sandbox, slightly hollow), gate the refugio door until slice 6, or keep both dev-only. **Ruled
  2026-07-28: they stay open.** Batch C softened the hollow edge — Nutria's card now says plainly
  she's company, not a verb, so the dead chip no longer reads as the player's failure to find
  something.
- **Slice-6 rulings still open** (carried from the 07-26 pass): how Build is input (contextual
  same-press vs contact-ability vs 2nd button); Herd feel (self-driving ~60 lines vs piloted ~200);
  material costs + whether a reach may visibly stall.
