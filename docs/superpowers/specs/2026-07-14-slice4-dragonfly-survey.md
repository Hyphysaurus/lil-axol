# Slice 4: The Dragonfly — Survey

**Date:** 2026-07-14 · **Status:** DRAFT — pending design review + Maram's reach-2 map
**Depends on:** slice 5 (reach-map ingester, live), the companion rig (Kind.DRAGONFLY registered,
frames built), the scout dragonfly (diegetic pass 1), master design §verbs ("dragonfly SURVEY =
reveal hidden sources + O2 bioindicator; pollination RETIRED").

## 1. Intent

The dragonfly joins the roster as the third companion, rescued on **reach 2 — Maram's next
painted map**, entered through the canals' dormant east portal. Her verb is **SURVEY**: an
on-demand sweep that makes the invisible visible — the reach's hidden wounds and secrets
shimmer for a few seconds, and she finishes by hovering over the worst-oxygen spot. She is the
player's *senses*, the way the turtle is their *force* and the frog their *mouth*.

## 2. The unlock (content contract — Maram's map authors this)

- Reach 2 `.tres`: `friend_kind = 3` (DRAGONFLY); the friend marker goes wherever the map
  wants her found — **surface or air-adjacent placement** (she's a flier; footing rule: in
  water or ≤ 4 cells above it, same as all v1 companions).
- Entry: reach 2's **west edge portal marker** (the canals' east door leads here); its
  `map_exits = { "west": "res://canals.tscn" }`. The canals' `.tres` gains
  `"east": "res://<reach2>.tscn"` — the dormant door wakes.
- Authoring suggestion (not binding): she suits a reach with AIR — tall sky, floating
  terraces, surface-heavy play; oxygen (`&"oxygen"` in `in_play`) should matter here since
  her bioindicator readout stars in it.

## 3. The verb — SURVEY

- **Input:** the shared partner-action button (the turtle's shell input) while the dragonfly
  is the ACTIVE partner — one button, verbs keyed by who travels with you (the Kirby rule).
- **The sweep:** tap → she spirals out from the player (~1.8s flight, radius ~180px, the
  scout's flight language reused), then REVEAL for **6 seconds**:
  - the uncapped leak pulses through murk,
  - sealed rubble / locked gates outline-glow,
  - **unfound curios glint through terrain** (the treasure sense),
  - grabbable chokes and the invasive school silhouette brighten.
- **The bioindicator finish:** she ends the sweep hovering ~2.5s at the reach's **worst
  oxygen point** (most grabbable-dense spot via reach_state's oxygen inputs; fallback: the
  leak; fallback: nothing — reach already breathing). Then returns to her follow slot.
- **Cooldown:** ~10s, shown as a small ring on the PartnerHud portrait (the shell stamina
  idiom). No cost — Survey is knowledge, and knowledge is free (conservation hook: observing
  IS the first restoration verb, per the knowledge loop).
- **Cozy contract:** reveals never mark quest arrows or map pins; they light the things
  themselves, in-world, then fade.

## 4. Reveal contract (implementation seam)

One group call: `get_tree().call_group("surveyable", "reveal", 6.0)`. Components opt in:
- `curio.gd` — glint amplified + visible through the land quad (temporary z/glow raise),
  ONLY for unfound curios.
- `destructible_rock.gd` — `breakable_glow` pulse boost (locked gates glow their tone).
- `leak_source.gd` — drip pulse + a rising mote trail.
- `debris_field.gd` / `invasive_school.gd` — brightened silhouettes.
Each owns its own look; Survey only rings the bell. The dragonfly companion itself extends
`companion.gd`'s data-driven rig — the sweep is a piloting-adjacent mode like the shell, but
non-interactive (she flies herself; ~120 lines projected).

## 5. Scout hand-off (continuity)

When the dragonfly is in the roster (`Settings.run_roster.has(3)`), the wild **scout**
retires — your partner has taken over the pointing, on your command instead of on a timer.
One line in scout_dragonfly.setup + a roster_changed listener.

## 6. Tests & gates

Headless: verb cooldown state machine; reveal group-call fans out (stub surveyable counts);
worst-oxygen pick against a synthetic reach_state; scout retirement on roster inclusion.
Plus the standing gates: all suites, three scene boots, reach-2 ingest audit green
(tools/audit_reach_map.ps1) before its .tres lands.

## 7. Risks

- **Reveal-through-terrain rendering** on the land quad (z 7): revealed glints need a
  temporary layer ABOVE 7 without breaking the z-map — pin: reveals render at z 8 (portal/FX
  plane), duration-bounded. Verify WebGL cost: reveals are ≤ a dozen small glows, 6s, rare.
- **One-button verb collision:** if BOTH turtle and dragonfly behaviors ever trigger on hold
  vs tap, define: HOLD = shell (turtle active), TAP = survey (dragonfly active) — the active
  partner disambiguates; never both.
- **Reach 2 doesn't exist yet** — tasks 1–3 (verb, reveals, scout hand-off) are testable on
  the canals with a dev roster; the unlock task blocks on Maram's map.

## 8. Task seeds

1. Survey verb core: input routing by active kind + sweep flight + cooldown + PartnerHud ring.
2. Reveal contract: "surveyable" group + the four component implementations + worst-O2 finish.
3. Scout hand-off + Field Guide card for the dragonfly rescue + feat &"first_survey".
4. Reach 2 integration: ingest Maram's map, .tres, portals wiring both ways, travel loop, deploy.
