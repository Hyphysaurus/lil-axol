# LilAxol — Build Status

**Updated:** 2026-07-01 (verified against code + git, commit `b6197aa`)
**Game:** cozy 2D pixel platformer/swimmer — an axolotl paint-to-cleans an oil-spilled cove;
the reward is the living world revealed underneath.

## BUILT (verified in code)

- **Axolotl controller** — walk/run/jump on land; swim/dive/buoyancy-bob/surface-hop in water;
  spray verb. Swim tuning is under a frozen-constants contract (see D-0003).
- **Data-driven animations** — `character_anim_set.gd` + `animation_controller.gd` + `axolotl_anims.tres`.
- **Paint-to-clean oil** — `oil_spill.gd` coverage mask + `oil_surface.gdshader`; spray erodes
  coverage; emits `cleanliness` 0..1 signal (group `oil_manager`).
- **Oil swim debuff** — up to 50% slower swimming in thick oil (`OIL_DRAG` in `axolotl.gd`).
  ⚠ built but never spec'd — design ruling pending (keep/soften/remove).
- **Cove modular architecture** — `CoveConfig` Resource (`cove_a.tres`) injected by `cove.gd`
  composition root into every component. Level-ready: one `.tres` per cove, zero code changes.
- **Atmosphere** — procedural sky/clouds/sun-moon + day/night (`day_night.gd`, 120s cycle,
  drives Mood CanvasModulate + water reflection).
- **Reactive seabed backdrop** — `seabed_backdrop.gd` tiles `water_clean_seabed.png` with
  `seabed.gdshader` edge blending; brightens murky→vivid with cleanliness.
- **Ecosystem fade-in** — `cove_life.gd` kelp/fish/bubbles, single global fade with cleanliness.
- **Win banner** — `restoration_banner.gd`, one-shot "Cove Restored" at cleanliness ≥ 0.999.
- **Cleanup FX** — `cleanup_fx.gd` particle bursts/rings/sparkles.

## BUILT, UNCOMMITTED (working tree, verified by headless boot 2026-07-01)

- **Juice + idle life** — squash/stretch, swim tilt + bubble trail, landing squash + dust;
  blink + AFK liedown→sleep chain; full SeethingSwarm strip set imported and wired into
  `character_anim_set.gd` (dash/crouch/sneak/wallgrab/wallclimb staged under Planned).
- **AxolotlTuning resource** — movement/spray numbers moved to `axolotl_tuning.tres`
  (defaults = the frozen D-0003 numbers); juice constants stay code-side per D-0002.
- **"A New Day" loop, Phase 1** — hold-R ring restart (`game/hud/new_day.gd`), banner→
  corner-sun handoff + one-time teaching subline, `win_threshold` on CoveConfig.
- **Touch controls** — floating stick + jump/spray/restart holds (`game/hud/touch_controls.gd`).
- **Audio, Phase 1** — Master→SFX/Ambience/Music buses, `Sfx` autoload (`game/audio/sfx.gd`),
  licensed assets staged (`assets/audio/SOURCES.txt`); verbs wired: splash in/out + hop,
  jump/land, spray loop, scrub ticks (pitch rises with cleanliness), milestone chimes
  (suppressed at 1.0 — the win stinger owns that moment), win stinger.
- **Addons installed** (project.godot): MetSys (Metroidvania System, autoload), lit (2D
  lighting, LitManager autoload + shader globals), mcp_bridge, SS2D/rmsmartshape, softbody2d.
  ⚠ Their extracted repo folders (SampleProject/, example/, examples/, samples/, scenes/,
  scripts/, root icon PNGs, README/LICENSE) are squatting at the project root — needs a tidy.
- **Gamepad bindings** — full joypad InputMap (stick + D-pad move, A jump, X/RT spray, B run,
  RB dash, Back = new day, Start/Esc = `menu`).
- **Title veil + settings + rest card** (2026-07-02, spec
  `2026-07-01-title-settings-design.md`) — living-cove title screen, tabbed settings
  (audio buses / rebindable controls / visual toggles) persisted via the `Settings` autoload
  to user://settings.cfg, Esc/Start pause card with resume/settings/new day/quit. main.tscn
  is now the app shell (Mario: game will grow beyond one scene). UI lock keeps gameplay
  input neutral under menus; adversarial review findings fixed (see spec Status).
- **Localized ecosystem reveal + caustics** (2026-07-02, cleaning-depth Layer 3, partial) —
  kelp/fish now sample the oil film above their own spot (`reveal` shader uniform per
  instance): life blooms exactly where you scrubbed, kelp first, fish once ~15% healed.
  Water caustics scale 25%→100% with cleanliness. Hidden critters + per-fish thresholds
  from the spec remain open.
- **Clean Wake Dash** (2026-07-02, spec `2026-07-02-wake-dash-sit-shore-meter-design.md`) —
  the mapped-but-unused `dash` action is now a swim burst that erodes the oil film along
  its path (spray_at, radius 16). New Dash tuning group on AxolotlTuning; D-0003 untouched.
- **Sit & Watch** — ↓ while idle on land sits (staged `sit` clip); camera eases 3.0→2.55
  while sitting or napping; any input stands up.
- **Sludged shore** — sand + beach grass start oil-matted (`sludge` uniform: dark drooped
  blades, streaked dim sand) and heal a beat behind the water via `shore_health.gd`.
  Grass also got per-blade brightness variance.
- **Restoration meters** (Terra Nil) — top-left water gauge (% + milestone notch pulses)
  with kelp/fish stage minis driven by cove_life's exact envelopes (`restoration_meter.gd`);
  hides while menus are up.

## DESIGNED, NOT BUILT

- **Cleaning depth spec** (`docs/superpowers/specs/2026-07-01-cleaning-depth-design.md`) — PROPOSAL:
  - Layer 1: oil thickness ramp toward source + sheen-vs-sludge shader states — unbuilt
    (mask is symmetric-blotchy; no matte sludge state).
  - Layer 2: cap-the-leak `LeakSource` + interact verb — zero code; art IS staged
    (`assets/props/industrial/`, barrel_leaking/valve variants).
  - Layer 3: incremental reveal (per-fish thresholds, caustics × cleanliness, hidden critters)
    — unbuilt; caustic hook is one multiply in `water.gdshader:53`.
- **Atmosphere spec add-ons** — drifting cloud sprites (open question; procedural clouds were
  improved instead), mood-swap skies (deferred to future coves).

## NOT DESIGNED (holes)

- ~~Post-win game loop~~ → DESIGNED, **Phase 1 BUILT** (uncommitted): "A New Day" hold-R
  restart + banner handoff (`specs/2026-07-01-game-loop-post-win-design.md`). Multi-cove
  stays deferred with an approved blueprint inside that spec.
- ~~Audio~~ → DESIGNED, **Phase 1 BUILT** (uncommitted): verbs make sound
  (`specs/2026-07-01-audio-design.md`). Phases 2–5 (CoveAudio ambience + healing low-pass,
  earned music, day/night mix, bespoke Ableton pass) still open.

## GOTCHAS / LOOSE ENDS

- `shaders/oil.gdshader` is **orphaned** (superseded by `oil_surface.gdshader`) but carries the
  repo's only uncommitted change (fbm/rainbow rewrite). Decide: commit or delete.
- `newoilset.png` + `waterpack.png` at project root: unreferenced 1536×1024 source sheets being
  imported for nothing (waterpack = spray-backpack concept art). Move under `assets/` or exclude.
- 144 of 145 prop sprites unused (industrial 52, oil 29, water_polluted 22, water 21, terrain 11,
  decor 10). Only `water_clean_seabed.png` is consumed.
- `dash` InputMap action defined, never read — candidate for the Layer-2 interact verb.
- Day length is 120s (the 20s debug value is gone); confirm as shipping value.
- Merged branches `feat/win-state-and-hygiene`, `refactor/cove-modular-architecture` not deleted.
