# Wake Dash · Sit & Watch · Sludged Shore · Restoration Meters — Design

**Date:** 2026-07-02
**Status:** BUILT (2026-07-02, uncommitted) — verified by headless + real-renderer boot.
Needs a feel playtest: dash speed/time, sit camera zoom (2.55), shore heal rate (0.3/s).
**Context:** Four additive features: the two build-now ideation winners, plus Mario's asks —
grass/land visual polish that starts oiled, and Terra Nil-style restoration meters.

## A. Clean Wake Dash (Sunshine-joy × Restoration)
Swim-only burst on the existing (mapped, unused) `dash` action: velocity = input direction
(or facing) × `dash_speed`, for `dash_time`, with `dash_cooldown`. While dashing the axo
erodes the oil film along its path via the same `spray_at` group call the spray uses
(smaller radius) — sparkle trail + scrub ticks come free from that path. Dash grants the
surface-hop grace so a surface-ward dash can crest the waterline. New `Dash` tuning group
on AxolotlTuning (speed 240 / time 0.3 / cd 0.8 / clean radius 16); all frozen D-0003
numbers untouched. Plays the staged `dash` clip; takeoff stretch + splash sfx.

## B. Sit & Watch (game-loop spec Phase 5's sit verb)
Press ↓ while idle on land → sit (staged `sit` clip); any other input stands up; swimming
clears it. While sitting (or asleep in the AFK chain) the camera eases from zoom 3.0 to
~2.55 and back — the cove becomes the show. No new InputMap action.

## C. Sludged shore that heals (grass + land polish)
`sludge` uniform (0..1) on wind_grass + sand shaders: oiled grass is dark, drooped
(height −35%), and barely sways; oiled sand is dimmed with dark horizontal oil streaks.
A new `ShoreHealth` component (cove.tscn) self-wires to the `oil_manager` cleanliness
signal (banner idiom) and eases sludge → (1 − clean) at 0.3/s — the shore heals a beat
behind the water. Grass also gets per-blade brightness jitter (polish, always on).
Shader defaults keep `sludge = 0` so other wind_grass users are unaffected.

## D. Restoration meters (Terra Nil)
`RestorationMeter` CanvasLayer (92): top-left stack — main water gauge (cleanliness %,
milestone notches at 25/50/75/100 that pulse when crossed) over two mini-gauges that track
the actual sim stages: kelp (smoothstep 0→35% of the heal) and fish (15→55%), matching
cove_life's envelopes so the meters never lie. Code-drawn in the banner idiom; label shows
percent. Hidden while any menu is up (UI lock signal); persists after the win — a full
meter is its own reward.

## Out of scope
Land dash / Celeste tech (bible: deep movement is Lil Ninja's pillar), meter entries for
music/critters (arrive with their systems), shore critters.
