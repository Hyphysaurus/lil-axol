# Atmosphere & Backdrop Art — Design Proposal

**Date:** 2026-07-01
**Status:** CORE IMPLEMENTED (commit `b6197aa`, 2026-07-01) — add-ons still open, see Build outcome below
**Context:** Mario wants to fold real 2D art (skies, oceans) into the cove. Paint-to-clean's
core reward is *revealing the world underneath* — good backdrop art amplifies exactly that.

## Asset research findings (verified, not guessed)

Surveyed the shared Asset Library + the project's own `assets/props/water`.

**Usable, on-style (pixel-art):**
- **Project's own** `water/water_clean_seabed.png` (**88×68** — a little coral/seaweed/bubble
  seabed vignette) and `water_clean_surface.png` (**173×61** — a wave strip). Cohesive pixel
  art, horizontally tileable. **Caveat:** they're small *tiles*, not backdrops — must be
  tiled, and they carry baked mid-blue lighting that won't auto-respond to day/night or the
  healing tint.
- **Library — Pixel Art Tileset Collection GDM:** full pixel skies + cloud sprites + 3-frame
  animated water. *Pirate Ship* theme (sky 672×528, clouds, water 64×32) is the strongest
  ready set; *Seaside Cave* (sunset) and *Roseate Moonrise* (night) are mood variants.

**Do NOT use:** GodotSkies / AR Ocean (3D-only), Tiny Swords clouds & foam (cartoon — clashes
with the pixel aesthetic), platformer/isometric tilesets (wrong scale/projection).

## The key tension

The **procedural sky is already good** — `day_night.gd` smoothly blends midnight→dawn→noon→dusk
and feeds the horizon colour into the water reflection. Static sprite skies can't do that
blend without cross-fading multiple sprite sets (complex, and you'd lose the smooth cycle).
**So: don't replace the sky.** Spend the art budget where it pays off most and where shaders
are weakest — the **underwater world the player uncovers by cleaning.**

## Recommendation: a reactive pixel SEABED backdrop (keep procedural sky)

Add a tiled `water_clean_seabed` band along the floor of the water column, **behind** the
procedural water tint, as the payoff layer for paint-to-clean:

- **Placement:** a parallax band at `seabed_y`, tiled across `[water_left, water_right]`.
  z-index below the water (z<5) so the procedural water + oil film sit over it.
- **Reacts to day/night:** `modulate` tinted by the CanvasModulate mood colour (or a lerp of
  it) so it lives in the same light as everything else — solves the baked-lighting caveat.
- **Reacts to cleaning (the point):** its brightness/saturation rises with `cleanliness`
  (drive `modulate` from the same signal CoveLife uses). Murky/dim under oil → vivid living
  reef as you scrub. This makes "reveal the world underneath" *literal*.
- **Repetition control:** vary per-tile `flip_h` + slight `modulate` jitter + overlap the
  existing CoveLife kelp/fish so the tiling reads as a reef, not wallpaper.
- **Fits the DI pattern:** a `SeabedBackdrop` component, config-driven (tile texture, band
  height), injected by `cove.gd` and wired to the cleanliness signal.

**Cost:** one component + scene node. No new shaders. Uses on-style art you already own.

### Optional add-ons (only if wanted)
- **Cloud sprites** (Pixel Art Collection) drifting over the procedural sky for depth — cheap,
  additive, keeps the day/night blend.
- **Mood-swap skies** (Pirate/Seaside/Roseate) as a per-cove aesthetic pick for *future levels*
  — a static backdrop per cove is fine when each cove is its own scene.

## What I explicitly do NOT recommend
- Replacing the procedural sky with sprite skies (loses day/night blend).
- Tiny Swords clouds/foam (style clash with the pixel axolotl).
- Tiling the surface strip over the whole surface (the water shader already does the surface
  better, with waves + reflection + the oil film).

## Open questions for Mario
- Do the project's `water_clean_*` tiles cohere with the axolotl's pixel style to *your* eye?
  (They're decent, but style-match is a taste call — this is the one thing I can't judge for you.)
- Seabed backdrop only, or also want drifting cloud sprites over the sky?
- Save the mood-swap skies for per-level variety later?

## Out of scope
Cleaning depth (separate spec), audio, multi-cove level flow.

## Build outcome (2026-07-01 audit)
The core recommendation shipped in `b6197aa` with three accepted deviations:
- **No parallax band** — plain Sprite2D tiles (fine for a single-screen cove; revisit if coves scroll).
- **Per-tile modulate jitter replaced** by a new `seabed.gdshader` (top/edge/bottom fades +
  depth tint matched to the darkened floor polygon) — melts seams instead of jittering tiles.
- **"No new shaders" cost claim exceeded** by that same shader; worth it, the band reads as
  environment rather than a sticker.
Cloud add-on answered differently than spec'd: the procedural `clouds.gdshader` was improved
(gap mask, belly wobble, softer horizon) instead of adding sprite clouds — sprite clouds remain
an open taste call. Mood-swap skies stay deferred to future coves. Tile texture/colors are
consts on SeabedBackdrop, not CoveConfig — lift them when a second cove needs a different reef.
