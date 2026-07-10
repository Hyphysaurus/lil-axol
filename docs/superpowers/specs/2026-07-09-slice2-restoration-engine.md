# Slice 2 — The Restoration Engine (Terra Nil core)

**Date:** 2026-07-09
**Status:** Draft for review (Maram)
**Parent:** `2026-07-07-living-watershed-master-design.md` §3 (variables/verbs/recipes), §3.5
(invasive fish), §3.6 (barrel economy), §3.7 (recoverable fail)
**Builds on:** Slice 1's WorldState persistence + the shipped cove systems (oil mask, debris,
pests, feats, banner, configs)

---

## 1. Goal

Replace the single cleanliness meter with a **system of ecological variables, chained
thresholds, and habitat recipes** — restoration you *read and reason about*, not a bar you
fill. Ship it retuned onto the two live reaches without breaking anything the player already
does. No new verbs this slice (dragonfly/otter verbs land with slices 4/6); the engine gives
the existing verbs new *meaning*.

## 2. Architecture — one component, derived variables, spatial systems stay

**The oil mask stays the source of truth for toxicity.** It is already spatial, persistent,
shader-driven, and tuned; the engine *reads* it, never replaces it.

New per-scene component **`game/cove/reach_state.gd`** (injected like everything else, group
`"reach_state"`), owning the canonical five variables, each 0..1 where **1 = healthy**:

| Variable | Definition (v1, concrete) | Moved by |
|---|---|---|
| **Purity** (inverse toxicity) | `oil.current_clean` — read straight from the mask | spray, bubble, dash-wake (existing) |
| **Oxygen** | `1 - alive/total` over the reach's **choke load** = everything in group `"grabbable"` (floating debris + PEST-mode flies; DRAGONFLY-mode flies never join the group, so the healed-water swarm can't crater the count — design-review I1). `total = debris_count + pest_count` from config; zero-choke reaches hold 1.0. Honest note (I2): pests also self-clear as the water heals, so in practice **Oxygen = the debris chokes, cleared via the frog** — the pip and any copy say "chokes", not "pests". **Authoring invariant:** every debris position must sit within the frog's surface reach (tongue 56px from the waterline); a headless test enforces it | frog tongue (existing); turtle/flow deepens it in slice 6 |
| **Clarity** | `minf(1.0, 1.0 - 0.12 × invasives_alive)` — the cap IS the definition (the redundant stir term from the draft is dropped, M4). Unresolvable until the otter herds them (slice 6): a deliberate, visible teased lock | *nothing yet* |
| **Invasive** | `1 - alive/total` invasive fish (1.0 where none spawn) | otter herd (slice 6) |
| **Vegetation** | recipe outcome, not a verb, **gated per-reach** (design-review I3, matching master §3.2): the marsh's REEDS are Purity-gated (`Purity ≥ 0.7`, mud-bank-clean rule) so the greens-return payoff works pre-otter; EELGRASS (post-otter clear-water reaches) is Clarity-gated (`Clarity ≥ 0.7 AND Purity ≥ 0.8`). Grows 0→1 over ~20s while its gate holds, regresses at ×0.25 rate when it fails. The gate lives on CoveConfig (`vegetation_gate: purity` \| `clarity`) | systemic |

`reach_state` recomputes on a **2Hz poll as the authoritative path** (pest buzz-off emits no
signal — M3), with the existing signals (`cleanliness`, curio/debris frees) as instant pokes,
and emits `state_changed(state: Dictionary)`. **No per-frame work, no per-frame saves.**

**Health** (the meter the player already knows) = the weighted blend **normalized over the
reach's IN-PLAY variables only** (design-review C1): CoveConfig authors `in_play`
(hub = `[purity]`; estuary = `[purity, oxygen]`), and Health = `Σ(wᵢ·vᵢ)/Σ(wᵢ)` over that set.
Consequences, verified: the hub's Health ≡ Purity ≡ today's cleanliness (byte-identical meter);
the estuary reads ~96% at its recipe-win instead of a nonsensical 68%. Variables the player
cannot yet move (Clarity/Invasive/Vegetation pre-otter) stay OUT of Health — the teased lock
lives in the pips, not as a meter that can never fill. Weights (when >1 variable in play):
purity 0.7 / oxygen 0.3 for the estuary.

**The meter's kelp/fish mini-gauges keep reading `cleanliness`** (not Health): the actual kelp
and fish in the water animate from cleanliness (`cove_life`), and the meter's own contract is
that it can never disagree with what the player sees (design-review I4).

## 3. Win recipes — config data, and the pre-otter marsh answer

`restoration_banner` stops hardcoding its gate. **CoveConfig gains a `win_recipe`**
(Dictionary of variable → min threshold; empty entries skipped), evaluated by the banner on
`state_changed` + the existing `notify_progress` pokes (friends/vents unchanged as extra
conditions):

- **Hub:** `{ "purity": win_threshold }` — the purity key always reads `cfg.win_threshold`
  (single source of truth, M1); with the banner's unchanged companion/vent ANDs this is
  byte-for-byte today's hub experience (review-verified).
- **Estuary:** `{ "purity": win_threshold, "oxygen": 0.9 }` — the marsh now *requires* the
  debris chokes cleared (≥4 of 5 at these counts), which is the frog's verb gating progress
  for real. (Pests self-clear as water heals — they're pressure and flavor, not the gate; I2.)
- **Restored-spawn coherence (design-review C2):** `DebrisField` and `PestField` skip spawning
  entirely when `WorldState.is_restored(cfg.id)` — a restored reach must reload READING
  restored (Oxygen 1.0, pips lit), mirroring how the root already retires the leak. Without
  this, a healed marsh reloads at Oxygen 0.55 with a dark pip — the master §7 "it stays alive"
  promise visibly broken.
- **Deliberately NOT in any recipe yet: Clarity/Invasive.** The marsh restores with the
  shadows still schooling — the banner subline acknowledges it (see §5). When the otter
  arrives (slice 6), the estuary's recipe deepens and the refugio completes the story. A
  restored-with-an-asterisk reach is the metroidvania tease made systemic.

## 4. The invasive school (ambient antagonist, pre-otter)

New `game/cove/invasive_school.gd` + config `invasive_count` (hub 0, estuary 5):

- Art: the **Smolque goldfish** (owned, verified stand-in — a goldfish IS a domesticated
  carp), murky olive-tinted, slightly larger than natives, swimming a low lazy patrol near
  the bed. Static frames + the existing fish swim-waggle skew (cove_life idiom).
- Behavior: drifts as a loose school; **shy** — eases away from the axolotl (never a threat,
  cozy). Each fish contributes `stir`: a faint sediment plume particle + the Clarity cap.
- Not grabbable (never joins the group — the frog's auto-tongue scans only `"grabbable"`,
  review-verified safe), and its `spray_at` is custom scatter-and-regather — spray can
  never delete it (teaches "my current verbs don't solve this", cozily).
- Field Guide: first close approach triggers an **ENCOUNTER card** — a new card *type*
  (design-review I5), keyed `enc_estuary_school` in its own namespace so it neither joins
  the curio tally (`count_for` counts collectibles only) nor collides with `curio_<i>`
  WorldState marks. Card: "Shadow in the Water" — tilapia/carp, the 1970s introductions.
  Echo-suppressed like every mark.

## 5. Surfacing the state — pips, not dashboards

- Under the existing restoration meter: **four small variable pips** (Purity, Oxygen,
  Clarity, Vegetation; Invasive folds into Clarity's pip tint pre-otter). Each pip = a tiny
  icon + arc, Apollo-tinted, lighting up as its variable crosses 0.5/0.9. Tap/hover does
  nothing yet (the browsable Log is queued separately) — pips are ambient literacy.
- **Banner sublines** become recipe-aware: restored-with-asterisk marsh reads
  *"the water runs clear — but shadows still school in the deep"*.
- Milestone bursts/chimes: unchanged (they key off Purity milestones as today).

## 6. Barrel → material (the §3.6 economy, collection half)

- Purifying any barrel (leak cap, drifting barrels) now also pops a **Reclaim**: a floating
  cleaned-metal token that drifts up; collect by touch → `material +1` for this reach.
- **WorldState** stores `material` per cove (marked on collect, echo-suppressed as usual).
- HUD: a small material tally beside the Shine orb (icon: a barrel ring), visible only when
  material > 0 — silent until the economy exists.
- **Spending** lands with the otter's Build verb (slice 6) — this slice only banks it. The
  spec's fail-vector "material stall" is therefore deferred with it (§3.7 note).
- Shine values unchanged; Reclaim is parallel to (not replacing) the "Spring Clean" feat.

## 7. Backslide (the recoverable-stakes vector this slice ships)

Already half-built: pests re-oil (capped, D-0005). Slice 2 makes backslide *legible*:
- While any pest lives, the Oxygen pip breathes dimly (pressure you can see).
- **No new punishment mechanics** — backslide stays gentle pressure + visibility, per §3.7.

## 8. Persistence

WorldState per cove adds: `material: int`, and on exit the five variables snapshot
(`vars: Dictionary`) purely for **re-seed display continuity** (the sources — mask fraction,
debris/pest counts — already persist or re-derive; variables recompute on load, the snapshot
only smooths the first-frame meter so it doesn't flash 0). Save cadence: milestones + exit,
unchanged. Version stays 1 (all new keys have safe defaults).

**Echo guards (M2): all three NEW save sources go through echo-suppressed paths** — the vars
snapshot is written from `cove.gd._exit_tree` (already `_echo`-guarded), never from a
reach_state exit hook; material-collect and the encounter card check `cove_root.is_echo()`
exactly as `curio_field` does today. An echo run must not be able to touch any of them.

**Material supply note (M5):** at current authoring the hub banks up to 3 material (leak
barrel + 2 drifters) and the estuary only 2 (no leak). Spending arrives with the otter's
Build (slice 6) — its costs must respect these supplies, and the master §3.7 "regenerating
trickle guarantees recovery" invariant needs an estuary answer (drifting barrels re-spawn
per-visit on unrestored reaches, which may suffice — decide in slice 6's spec).

## 9. Testing

- **Headless suite additions** (`tests/test_reach_state.gd`): reach_state math — pure
  functions fed synthetic inputs: in-play-normalized Health (hub set ≡ purity; estuary
  weights), clarity cap with N fish, per-reach vegetation gates (purity-gated growth +
  regression over stepped time), win-recipe evaluation (empty recipe passes; multi-key
  requires all; purity key reads win_threshold).
- **Authoring invariant test:** every `debris` the estuary spawns must be reachable by the
  surface-clamped frog (position within tongue reach of the waterline) — the win depends on
  it (design-review I2).
- Existing WorldState suite untouched + still ALL PASS.
- Manual (deploy): hub plays identical; estuary win now demands debris+pests cleared; school
  scatters and re-gathers; pips read; Reclaim tokens collect and persist; asterisk subline.

## 10. Scope cuts (deliberate — do NOT "fix")

- No algae-mat entities yet (Oxygen v1 = debris + pests only; mats join with the marsh
  deepening later).
- No Clarity/Invasive resolution — that IS slice 6's otter. The cap is the tease.
- No variable tooltips/browsable log (queued separately).
- No material spending, no dead-end/stall mechanics (slice 6, with Build).
- Eelgrass visual = reuse the reeds component tinted submerged-green at vegetation ≥ 0.6
  (a fuller eelgrass pass belongs to the art slice).
