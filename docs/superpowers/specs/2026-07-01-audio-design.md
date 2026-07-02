# Audio ("Hear the Cove Come Back") — Design Proposal

**Date:** 2026-07-01
**Status:** PHASES 1-3 BUILT (P1 2026-07-01; P2-3 "the cove breathes" + earned music 2026-07-02) — buses + `Sfx` autoload + all Phase-1
verb sounds wired (splash in/out/hop, jump/land, spray loop, scrub ticks with rising pitch,
milestone chimes suppressed at 1.0, win stinger). Phases 2–5 open; the open questions below
still need Mario's rulings. (Spec synthesized from a 2-design judge panel: SFX-first won;
the ambience design's healing-mix ideas grafted in.)
**Context:** The game is 100% silent — no files, no players. The reward loop (scrub oil,
watch the world bloom) lands mute, and the coming post-win epilogue is where silence hurts
most. **Every sound file named below was verified on disk in the Asset Library today.**

## The arc

Silence → ambience → **earned music**. An oiled cove sounds muffled and dead; cleaning
literally opens the mix; music itself arrives only as the restoration prize. Player verbs
get sound first (movement feel is the pillar), the world second, music last.

## Architecture (code-first, no addons)

- **Buses:** Master → SFX / Ambience / Music, saved as `default_bus_layout.tres`
  (inspector-tunable; no runtime bus creation).
- **`game/audio/sfx.gd` autoload** — 8-player AudioStreamPlayer pool + a code-built
  Dictionary of AudioStreamRandomizer entries (variations, random_pitch ~1.05–1.1).
  API: `Sfx.play("splash")`. Plain non-positional players — one screen, panning buys nothing.
- **`game/cove/cove_audio.gd`** — one node in cove.tscn, injected via `cove.gd` like
  CoveLife; self-wires to the `oil_manager` group exactly like restoration_banner.gd.
- **The healing mix (graft):** one AudioEffectLowPassFilter on Ambience (+Music later),
  cutoff swept perceptually in octaves — `700.0 * pow(2.0, clean * 4.7)` (~700 Hz oily →
  ~18 kHz clean) — smoothed with `move_toward(x, target, delta * 0.5)` so the soundscape
  heals at exactly the kelp's rate. **SFX bus stays crisp** (verbs must read responsive).
  While submerged, clamp the target ≤2.5 kHz (diving muffles the world; surfacing pops it
  back) — needs a tiny `submerged(bool)` signal on axolotl.gd.

## The first five sounds (by feel-impact; exact hooks)

1. **Splash in/out** — Helton Yan `Wet Splash 001–006` at `_enter_water`/`_exit_water`
   (axolotl.gd:167-172); enter full, exit lighter (matches the 1.0/0.7 particle amounts);
   tiny variant on surface-hop (:150). Highest per-line feel win.
2. **Spray loop** — TomMusic `Waterspray` toggled exactly where `_spray_p.emitting` is set
   (axolotl.gd:88). If it reads "spell": `SFX_Pop_Bubble_Water_Loop_1` pitched up.
3. **Scrub-bite** — bubble-pop ticks (`SFX_Pop_Bubble_Single_1-3`) inside the `removed>0`
   `_spark_cd` branch (oil_spill.gd:117-120), `pitch_scale = 0.9 + current_clean * 0.4` —
   progress becomes audible. **Spraying clean water stays silent** (non-negotiable, or the
   bite feedback dies). May need its own ~0.12s audio cooldown vs the 0.05s `_spark_cd`.
4. **Milestone chime** — `SFX_Chimes_Glowing_Stars_1` at the `_fx.pop` branch
   (oil_spill.gd:121-123), pitched up one pentatonic step per milestone. **Suppress at the
   1.0 milestone** — MILESTONES includes 1.0 and the banner fires at 0.999, so chime and
   win stinger would stack.
5. **Jump/land** — TomMusic `Dirt Jump` (~1.3 pitch for a small critter) at axolotl.gd:123
   + `Dirt Land` via a one-line was-airborne check.
   Plus (two lines): **win stinger** — `Area Discovered.wav` in the banner's `_fired` branch.

## Ambience & music

- **Phase 2 bed:** TomMusic `Sea.ogg` (loop-imported) always on behind the low-pass, plus a
  life layer (`Grassy Field Loop.wav`) faded −60 → −8 dB on the cleanliness signal. Tune the
  curve so first birds arrive ~30% clean, not 60% (avoids double-attenuation with the filter).
- **Phase 3 day/night:** 2-line `time_of_day()` getter on day_night.gd (`has_method`
  fallback so CoveAudio degrades gracefully); day-weight smoothstepped around sunrise 0.22 /
  sunset 0.78; life gain = cleanliness × day-weight; ~4 dB duck at deep night.
- **Music is EARNED:** Music bus silent until ~85% clean; a Cozy Tunes track (`Gentle
  Breeze` or `Wildflowers By The River`, both on disk) fades fully in with the banner.
  Fallback if playtests want earlier warmth: a quiet always-on pad that blooms.
- **Data-driven:** optional `ambience/life_day/life_night/music` AudioStream exports on
  CoveConfig (~4 lines, null-safe) — honors "one .tres per cove, zero code changes."

## Sourcing & licensing

Asset Library packs are the ship path for phases 0–3; Ableton is polish, not a gate.
**License gate (Phase 0, ~30 min):** SwishSwoosh + Cyberwave ship GameDev.tv License 2.0,
Helton Yan has LICENSE.txt, Starter Pack links a royalty-free license — but the local
**TomMusic and Cozy Tunes readmes contain NO license terms** (verified today); check their
itch pages before shipping. Copy chosen files (not reference) into
`assets/audio/{sfx,ambience,music}/`, mirroring the assets/props habit.

## Build order
- **Phase 0** — license check + staging (~30 min).
- **Phase 1** — verbs make sound (~1 day, ships alone): buses + Sfx autoload + the five
  sounds + win stinger. Silent game → feels-complete in one pass.
- **Phase 2** — the cove breathes (~3–4 hrs): CoveAudio, sea bed + life layer,
  cleanliness→low-pass sweep, `submerged` clamp.
- **Phase 3** — time and reward (~2–3 hrs): earned music, day/night crossfade,
  CoveConfig audio exports.
- **Phase 4** — bespoke polish (optional, ~1 day in Ableton, vampfever pipeline):
  C-pentatonic `mus_base` 45s pad / `mus_alive` 60s kalimba (non-divisors of the 120s day so
  loops don't phase-lock), authored life stems, pentatonic chime kit; replace any pack sound
  playtests flag as tonally wrong. This also drains the mixed-packs cohesion risk over time.
- **Phase 5** — CONTINGENT on cleaning-depth approval: leak-cap clunk (`Impact Metal Hatch`
  + `SFX_Chest_Open` layer), sludge scrub variants. Do not start before that spec is ruled on.

## What I explicitly do NOT recommend
- Middleware/addons, positional 2D emitters, per-frame oil-mask audio polling, beat-sync.
- A footstep-surface system yet (jump/land carries it; `Dirt Walk/Run 1–5` exist for later).
- Audio settings UI this pass (buses make it trivial later); wiring anything to unused `dash`.
- Import gotcha: **ogg `loop=true` must be set per file** or ambience plays once and dies.

## Open questions for Mario
- **The one real fork:** earned music (silent until ~85%, arrives with the banner —
  recommended; music is the prize) vs a quiet pad from the start that blooms as you clean?
- OK to touch two existing files: `submerged(bool)` signal on axolotl.gd + `time_of_day()`
  getter on day_night.gd? Everything else is strictly additive.
- Should oil/underwater muffle also color the SFX bus (your own splashes sound sludgy in
  oil — diegetic) or keep all verbs crisp (responsive)? Recommendation: spray always crisp,
  splashes muffled.
- License posture: gate shipping on the TomMusic/Cozy Tunes itch pages? Does the no-AI /
  attribution posture from Comfy Jam apply to this project's audio credits?
- Axolotl voice: a tiny ACNH-style chirp on jump/hop — nothing in the library fits, would be
  the one authored one-shot (5 min in Ableton). Phase 4 wishlist or skip?
- Confirm the 100% moment: suppress the fourth milestone chime so only the win stinger plays?

## Out of scope
Cleaning-depth sounds (until that spec is approved), audio settings UI, adaptive stems
beyond 2–3 layers, any music beyond one track + optional authored pair.
