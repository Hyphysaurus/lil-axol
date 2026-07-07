# Hub Pond & the Living World — Design

> **⚠️ SUPERSEDED 2026-07-07** by
> [`2026-07-07-living-watershed-master-design.md`](2026-07-07-living-watershed-master-design.md).
> The hub-and-spoke world, WorldState persistence + Echo runs, frog surface pivot, and marsh
> estuary all carry forward; the master spec re-frames everything around real Xochimilco ecology
> and a Terra Nil-style variable/recipe restoration system. Read that one.

**Date:** 2026-07-06
**Status:** Superseded — see banner above
**Original status:** Approved direction (Maram), spec for review
**Decides:** world structure, persistence, frog/estuary rework, companion roadmap
**Supersedes:** the open "modular world / which-companion-first" question in the review backlog

---

## 1. Vision

The cove becomes **Hub Pond** — the persistent home of a hub-and-spoke world. Every
spoke biome follows the bible's core loop (discover pollution → clean → restored →
wildlife returns → travel on), and every spoke is anchored by a **partner** whose one
verb owns a distinct **restoration category** and opens a distinct **gate type** from
the hub. The world is **fully persistent**: restored coves stay restored, forever.
Emotional arc, per the bible: *"I made this place better"* — and you can always swim
home and see it.

### The verb wheel (six partners, six biomes, zero style risk)

| Partner | Verb category | Restoration owns | Hub gate type | Biome (tileset) |
|---|---|---|---|---|
| Turtle ✅ | break (demolish) | rubble | plug walls | Hub Pond (procedural) |
| Frog ✅ | consume (tongue) | debris + pests | debris chokes | Marsh estuary (procedural + marsh kit) |
| **Dragonfly** (next) | **add** (pollinate) | bloom % | Gatebloom — regrow-to-reflood | Forest meadow (Legacy-Fantasy) |
| Otter | relocate (haul) | flow | counterweight locks | Forest creek (Legacy-Fantasy) |
| Bat | perceive (echosong) | luminosity + the *discover* beat | resonance seals, dark passages | Glowmoss grotto (MossyCavern) |
| Crow | replant (seed-drop) | erosion | seed-socket mechanisms | Coastal headland (Tiny Ocean) |

All partner art is SeethingSwarm (same artist as the axolotl — style match guaranteed).
Owned: axolotl, turtle, frog. To buy, one pack per slice as its slice starts:
Dragonflypack $11.99 → Lil Otter $11.99 → Batpack $11.99 → Crowpack $11.99 (~$48 total).
**Crane, owl, raccoon are citizens, not companions** (crane wades the restored marsh,
owl roosts in the relit grotto, raccoon rummages the restored creek bank) — they were
strictly reviewed and eliminated as verbs (redundant or tone-broken), but the bible
wants citizens, and they're perfect there. Citizen packs (Cranepack $14.99, Owlpack
$11.99, Raccoonpack $11.99) are optional later polish, bought only when their scene's
restored-state dressing pass happens — never blocking a slice.

This roadmap came out of a 7-candidate, 3-judge strict review (2026-07-06).
Key rulings preserved:
- **Dragonfly won the restoration axis** (Maram's top weight): pollination is the
  game's first *additive* restoration — everything shipped subtracts (scrub, grab,
  cap, break); Bloomdust puts life back in, with its own meter (bloom %) and its own
  thesis (*clean ≠ alive*). It also has the best story: `pest_fly.gd` already ships
  `Mode.DRAGONFLY` as the healed-water reward skin, so the wildlife that returns when
  you heal the estuary is what joins you — **partners recruited by restoration itself.**
- **Otter won gameplay + feasibility** (relocate = the one untaken verb category; the
  code already reserves Kind 2; counterweight locks move the *waterline*, expanding
  where the water-bound axolotl can natively swim). It builds second.
- **Sequencing compounds systems:** dragonfly builds the flying-follower plane and the
  two-leg fetch→deliver command; bat reuses the flight plane + node registry (its
  glow-moss wakes in additive chains, fixing its "spray-in-the-dark" knock); crow
  reuses the fetch-ferry with seeds. Each partner is cheaper than it would have been
  built first.
- Waterline gates (otter locks, Gatebloom flooding) are **pre-authored scene states**
  persisted like `cove_portal`'s cleared flag — never a dynamic water sim, and the
  frozen swim tuning is untouched.

### Bible compliance

One defining mechanic — Restoration — holds: every partner verb IS a restoration verb.
Bosses stay environmental disasters (the meadow's is a pollinator die-off: the water is
clean and the meadow is still gray). Animals are citizens; companions are citizens who
work alongside you, recruited by healing their homes.

---

## 2. World structure — Hub Pond

- The current cove IS the hub. Tutorial unchanged (first scrub, wake the turtle).
- Once restored, the hub is home: the portal ring grows as partners join. Estuary
  passage exists today; each future spoke adds one portal, gated by its partner's verb
  (`cove_portal` generalizes: the plug node varies by gate type, the `cleared` →
  fade → `change_scene` seam stays).
- **Partners idle in the hub** when not the active traveller: spawned as ambient
  versions at authored spots (turtle suns on a rock, frog on a lilypad, dragonfly
  patrols the reeds). Pure dressing — no verbs at home, tap one to swap it active
  (same contract as the partner-HUD chips).
- Hub wildlife density reads **total world restoration** (sum over WorldState), so
  finishing any spoke visibly enriches home. Cheap: it feeds the existing
  `cove_life` counts.
- Return trips: every spoke's exit portal back to the hub is open (no gate) once the
  spoke's entry gate has been opened. `exit_target` chains already support this.

## 3. Persistence — WorldState

New autoload **`WorldState`** (sibling of `Settings`, same store pattern as
`settings_store.gd`), saved to `user://world.save` via `ConfigFile`. Web exports
persist `user://` through IndexedDB, so lilaxol.vercel.app keeps saves.

**Per cove** (section = cove id, e.g. `hub`, `estuary`): `cleanliness` (float),
`friend_awake`, `vents_opened` (array of ids), `nooks_broken` (array), `portal_cleared`
(per portal id), `leak_capped`, `restored` (bool — the banner fired).
**Global:** `roster` (array of Kind), `active` (Kind), `version` (int, for migration),
`best_scores` (per cove, for Echo runs).

- **Save triggers:** milestone events only (rescue, vent open, nook break, portal
  clear, leak cap, restoration banner) + scene exit (portal cross, quit to title).
  No per-frame writes; cleanliness saves at milestones and exit, not continuously.
- **Load:** the Cove composition root consults WorldState in `setup()` before wiring
  children: a restored cove spawns with oil at 0, life at full, friend awake and
  following-eligible, vents open, portals cleared. Partially-cleaned coves restore
  their saved cleanliness as the oil mask's starting coverage (uniform re-seed of the
  saved fraction across the spill span — the mask bitmap itself is NOT saved).
- **Fresh profile:** no file → all defaults → exactly today's behavior. **Corrupt or
  future-versioned file:** back it up to `world.save.bad`, start fresh, log once —
  never crash, never silently overwrite the backup.
- **Echo runs (the arcade layer's new home):** on a *restored* cove, the DAY button
  offers an **Echo run** — replay that cove's restoration as a scored, transient run
  (re-oiled from config, feats/flow/leaderboard live, `run_score` seeded 0). World
  state is untouched: crossing a portal or ending the run snaps back to the restored
  world. Implementation: a `WorldState.echo` session flag the composition root reads
  *instead of* saved state; milestone saves are suppressed while it's on. New Day on
  an unrestored cove keeps today's meaning (restart the attempt).
- The Tide Board re-enables on Echo-run completion (its "blocking progress" problem
  dies once submitting a score no longer stands between you and the portal).

## 4. Frog pivot — surface + land

The frogpack's swim art is good (swimforward 6f @ 10fps, swimidle, 3 swim-tongue
directions); the jank was integration. Two changes, one rule:

- **Never dives:** for `Kind.FROG` the follow target's y clamps to `surface_y` while
  over water — it kicks along the surface (`swimforward`), rests splayed
  (`swimidle`), and hops on land and lilypads. Tongue keeps working from the surface
  (swim-tongue clips for water-adjacent snags, land-tongue on shore). No perch-picking
  AI needed — the marsh below is shallow and the surface is always a valid lane.
- **Integer scale:** `friend_scale` snaps to **1.0** (estuary config's 0.7 and the
  library's 0.85 both go). The 50×50 frame carries margin around the body; verify
  visually — if the frog reads too big, fix it in art with a one-time integer-aware
  resize of the strips. **Rule for all partners, now and future: no runtime fractional
  scaling of pixel art.** (`companion_library.gd` keeps its `scale` field for legacy
  reasons but every entry is 1.0 unless art-level resizing happened.)
- Optional polish, not required for the slice: pulse the surface-kick speed to the
  kick frames (kick-glide rhythm) if the constant-velocity slide still shows.

## 5. Marsh estuary — a real biome, not a tint

`estuary.tscn` currently instances `cove.tscn` under a green `CanvasModulate`. It
keeps the instancing (the cove kit IS the engine), but gains identity:

- **Geometry:** shallow — `seabed_y` raised toward `surface_y` (a marsh you could
  stand in), wider land margins and a mid-water mud bank islet. Numbers live in
  `estuary_a.tres` as always.
- **New set-dressing components** (each self-contained, injected by the composition
  root like vents/nooks, counts on CoveConfig): **lilypads** (float on the surface,
  frog hop-points, gentle bob), **reed/cattail clusters** (drawn polygons on the
  existing `wind_grass` sway shader, banks + shallows), **half-sunken log** (static
  perch/dressing). Lilypads join a small "perch" group the frog's land logic accepts.
- **Environment overrides:** a new optional `environment` sub-resource on CoveConfig
  (water tint, sand tint, backdrop mood, surface fleck color) that the composition
  root applies to the scene materials when present — replaces the CanvasModulate
  wash. Estuary: green-tea water, brown-umber sand, duckweed flecks. All values are
  named **Apollo** swatches (never literals — palette memory rule).
- Pests + debris stay (the frog's niche). The healed-water dragonflies
  (`pest_fly.Mode.DRAGONFLY`) now **foreshadow the recruit** — no extra work, the
  code already does this; slice 2 adds one lingering dragonfly with a recruit
  interaction after restoration.

## 6. Slice 2 preview — Dragonfly & the Forest Meadow (own spec before build)

Recorded here so the hub/save design accommodates it; it gets its own spec.

- **Recruit flow:** restore the marsh → one dragonfly lingers at a flower on the mud
  bank → spray-sparkle interaction joins it to the roster (first *recruited* partner;
  rescue = spray-clean stays the turtle/frog pattern).
- **Bloomdust verb:** point-and-click on the turtle's proven command rig — click a
  withered bloom; the dragonfly fetches a pollen mote from the nearest healthy bloom
  and dusts the target; it opens and becomes a new source (chains). Two-leg
  charge→act→rejoin, existing `MAX_COMMAND_TIME` net. It never touches `grabbable`/
  `blastable` — zero overlap with frog/turtle.
- **Flying follow plane:** the third follow mode (hover above the player, ignore
  water clamps) — built once here, reused by bat and crow.
- **Bloom registry + bloom % meter** beside the oil meter; meadow wildlife
  (bee/butterfly/hedgehog/squirrel sheets — owned) fades in on bloom count.
- **Gatebloom portal** in the hub: pollinate the giant withered flower on the dry
  ledge → roots part → the drained channel floods (pre-authored state swap, persisted
  like any portal) → swim to the meadow.
- **Meadow disaster:** pollinator die-off — the water is already clean; the meadow is
  gray until you re-chain the blooms. First cove where `has_water` play is minimal
  and the oil meter isn't the win condition (win reads bloom %).

## 7. Slicing

1. **Slice 1 — Foundations (this spec's build):** WorldState + load-on-setup + Echo
   runs; frog surface pivot + integer scale; marsh estuary (geometry, lilypads,
   reeds, environment overrides). No purchases.
2. **Slice 2 — Dragonfly & meadow:** recruit flow, Bloomdust, flight plane, bloom
   registry/meter, Gatebloom, meadow scene. Buy Dragonflypack.
3. **Then:** otter (creek + locks) → bat (grotto + echosong) → crow (headland +
   seeding), one spec each, citizens sprinkled as their scenes restore.

## 8. Testing

- **Save round-trip (headless):** write WorldState → reload scene tree → assert the
  composition root spawned restored-state (oil 0, friend awake, portal open).
  Version-migration and corrupt-file paths covered the same way.
- **Fresh-profile path:** no save file → behavior identical to today (guard test).
- **Echo run:** enter → world snapshot untouched after exit; score submits; no
  milestone saves during.
- **Frog:** surface clamp (never below `surface_y` over water), hop on lilypads,
  tongue still snags debris/pests, scale renders 1:1 pixels.
- **Visual review:** marsh identity + frog scale verified on the live web build
  (Mario reviews at lilaxol.vercel.app — the editor bridges are unreachable from
  this shell, so visual iteration goes through deploys).

## 9. Open items

- Frog at 1.0 scale: pending Mario's visual check (fallback = art-level resize).
- Echo-run entry UI: reuse the DAY button's hold-ring on restored coves (proposed) —
  confirm during build.
- Hub idle-partner spots: authored positions TBD during the hub-slice layout pass.
- Bible caveat carried forward: series art says "KayKit environments" (3D) — the 2D
  tileset reality (Legacy-Fantasy/MossyCavern/Tiny Ocean) remains the accepted
  deviation, per the asset-map ruling.
