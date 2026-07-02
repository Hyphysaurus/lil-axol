# Game Loop & Post-Win ("A New Day") — Design Proposal

**Date:** 2026-07-01
**Status:** PHASE 1 BUILT (2026-07-01, committed 2026-07-02) — banner corner-sun handoff + `restored`
signal, `win_threshold` hoisted to CoveConfig, `new_day.gd` hold-R ring + `restart` action.
Phases 2–5 (title card, rest card, dawn beat, afterglow) open. (Spec synthesized from a
3-design judge panel: session-framing won; grafts from the place-to-stay and multi-cove designs.)
**Context:** After "Cove Restored" fades, nothing happens — forever. No restart, no title,
no pause, no next anything. The game reads as a demo. This spec closes the loop with the
smallest structure that makes LilAxol feel complete, and records the approved blueprint for
multi-cove later without building it now.

## The shape

**main.tscn stays the only scene forever.** All framing is small code-built CanvasLayer
overlays in `restoration_banner.gd`'s exact idiom (StyleBoxFlat, layer 95 under PostFX 100).
**Hold-R → `reload_current_scene()` is the entire progression and reset system** — a full
clean fits one sitting, and the DI architecture makes reload free. "Reload is the save system."

## What happens after the banner (exactly)

1. Cleanliness crosses a single shared **WIN_THRESHOLD** — hoisted out of the banner's
   hardcoded `0.999` into CoveConfig (or one shared const) so the banner and any future
   gate (leak-capped? cove exit?) can never desync.
2. Banner fades in as today. During its hold, `day_night` eases to the next **dawn** over
   ~8s (shortest-forward wrap, capped) — the world answers your work with a sunrise.
3. Banner shrinks into a persistent corner sun/sprout glyph + a one-time subline:
   *"stay awhile — hold R for a new day"* (fades after ~6s). It also emits a `restored`
   signal / joins a `restored` group (~2 lines, future-proofing for afterglow content).
4. Nothing pauses, nothing is forced. The cove keeps living on the 120s clock —
   **designed free-play is the reward.**
5. **Hold R** (0.8s fill ring, release cancels) fades to black and reloads: fresh spill,
   fresh morning — a new day.

## Systems (each independently shippable)

| Phase | What | Cost |
|---|---|---|
| 1 — Epilogue + New Day | banner extension (glyph, subline, `restored` signal), WIN_THRESHOLD hoist, `game/hud/new_day.gd` hold-R + `restart` InputMap action | ~1 day; **game is loop-complete after this phase alone** |
| 2 — Title Card | `game/hud/title_card.gd`; living cove animates behind the veil (tree NOT paused); input consumed on dismiss; skipped after a New Day reload via a static flag (**verify statics survive reload in 4.7**; fallback = 3-line autoload) | ~½ day |
| 3 — Rest Card | Esc pause overlay: Resume / New Day / Quit (Quit hidden on web; P fallback if web fullscreen eats Esc); `PROCESS_MODE_ALWAYS` + pause-mode tweens; shares one restart routine with Phase 1. Test Esc during spray-hold and mid-banner | ~½ day |
| 4 — Dawn Beat + naming | `day_night.ease_to_time(t, dur)`; `CoveConfig.display_name` shown on the banner ("Kelpwash Cove Restored") | ~½ day |
| 5 — Afterglow | sit verb (hold ↓ while idle on land, slight camera ease, any input stands up — **no new InputMap action**) + **fireflies only**: one CPUParticles2D over the water, gated on `restored` + dusk/night via a new `day_night.time_of_day()` accessor | ~1 day |

## Persistence

**Nothing persists to disk in v1.** The only cross-reload state is the in-memory
"title already seen" flag. `user://` ConfigFile persistence (cove index + restored flags,
never the oil mask) arrives only with multi-cove.

## Multi-cove: deferred, blueprint recorded

Not in this layer. Start it only when (a) the single-cove loop playtests as complete AND
(b) the cleaning-depth spec decision lands — cove variety without those knobs is
geometry+mood only, and same-art fatigue hits by cove C. **Approved blueprint when ready
("The Drift Current"):** CoveDirector + an invisible-until-restored glowing exit current +
`cove_b.tres` loaded into the same cove.tscn; New Day then reads "a new cove, a new day."
`display_name` on CoveConfig pre-seeds this for free today.

## What I explicitly do NOT recommend
- Scoring, timers, stars, or any completion pressure — the epilogue is the prize.
- A save system now (premature for a one-sitting game).
- Persisting restored coves as clean-forever — it deletes the core fantasy on relaunch.
- Any visitor cast beyond fireflies in this layer (scope magnet; pixel-scale readability risk).
- Rebinding `dash` — it stays reserved for movement; sit uses held-down.
- Smuggling audio in here (separate spec — but the epilogue is where silence hurts most).

## Open questions for Mario
- **Export target:** desktop only, or web too? Decides Quit visibility and Esc vs P for pause.
- **Win ownership:** if cleaning-depth's leak ships, does "restored" become
  `cleanliness ≥ threshold AND leak capped`? One-line answer needed before Phase 1.
- **New Day target:** reload the same `cove_a.tres` (recommended), or a second .tres sooner
  (bigger spill, dusk start — `start_time` is already exported, nearly free)?
- **Name the cove now?** (e.g. "Kelpwash Cove") or keep the banner generic until multi-cove?
- **Post-win pacing:** keep the 120s day in the afterglow, or slow `day_length` for a longer
  golden hour?
- **Afterglow scope:** green-light Phase 5 (sit + fireflies) inside this layer, or keep this
  layer purely structural?

## Out of scope
Audio (separate spec), cleaning-depth layers, multi-cove implementation, save/settings UI.
