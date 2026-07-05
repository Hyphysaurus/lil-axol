// Apollo palette (AdigunPolack, lospec.com/palette-list/apollo) — the game's master colour set.
// Included by the procedural shaders so every generated visual snaps to the SAME palette. Values
// are the raw hex normalised to 0..1: the Compatibility renderer is sRGB end-to-end (no linear
// conversion), so these floats land on-screen exactly as the hex codes.
//
// ONE SOURCE OF TRUTH (shader side): edit a colour here and every shader that `#include`s this file
// updates at once. The GDScript mirror lives in game/palette.gd — keep the two in step. The SW_
// prefix (originally "Sweetie") now just means "swatch"; names match palette.gd one-to-one.

#ifndef APOLLO_INC
#define APOLLO_INC

// neutrals
const vec3 SW_INK   = vec3(0.035, 0.039, 0.078); // #090a14  darkest ink-navy
const vec3 SW_SLATE = vec3(0.125, 0.180, 0.216); // #202e37  dark slate
const vec3 SW_STEEL = vec3(0.341, 0.447, 0.467); // #577277  steel grey-teal
const vec3 SW_MIST  = vec3(0.659, 0.710, 0.698); // #a8b5b2  pale mist
const vec3 SW_FOAM  = vec3(0.922, 0.929, 0.914); // #ebede9  near-white
// water
const vec3 SW_AQUA  = vec3(0.643, 0.867, 0.859); // #a4dddb  pale surface aqua
const vec3 SW_CYAN  = vec3(0.451, 0.745, 0.827); // #73bed3  bright water
const vec3 SW_SKY   = vec3(0.310, 0.561, 0.729); // #4f8fba  sky blue
const vec3 SW_BLUE  = vec3(0.235, 0.369, 0.545); // #3c5e8b  mid blue
const vec3 SW_DEEP  = vec3(0.145, 0.227, 0.369); // #253a5e  deep blue
const vec3 SW_ABYSS = vec3(0.090, 0.125, 0.220); // #172038  deepest navy
const vec3 SW_TEAL  = vec3(0.224, 0.290, 0.314); // #394a50  muted dark teal
// foliage
const vec3 SW_MOSS   = vec3(0.145, 0.337, 0.180); // #25562e  deep forest
const vec3 SW_GREEN  = vec3(0.275, 0.510, 0.196); // #468232  green
const vec3 SW_FERN   = vec3(0.459, 0.655, 0.263); // #75a743  fern
const vec3 SW_LEAF   = vec3(0.659, 0.792, 0.345); // #a8ca58  light leaf-green
const vec3 SW_SPROUT = vec3(0.816, 0.855, 0.569); // #d0da91  pale sprout
// earth
const vec3 SW_SOIL = vec3(0.302, 0.169, 0.196); // #4d2b32  dark loam
const vec3 SW_LOAM = vec3(0.478, 0.282, 0.255); // #7a4841  loam
const vec3 SW_CLAY = vec3(0.678, 0.467, 0.341); // #ad7757  warm clay
const vec3 SW_SAND = vec3(0.843, 0.710, 0.580); // #d7b594  pale sand
// warm
const vec3 SW_EMBER = vec3(0.745, 0.467, 0.169); // #be772b  deep ember-orange
const vec3 SW_AMBER = vec3(0.871, 0.620, 0.255); // #de9e41  amber
const vec3 SW_GOLD  = vec3(0.910, 0.757, 0.439); // #e8c170  warm gold
// reds & pinks
const vec3 SW_ROSE    = vec3(0.647, 0.188, 0.188); // #a53030  rose-red / ember base
const vec3 SW_CORAL   = vec3(0.812, 0.341, 0.235); // #cf573c  coral/orange
const vec3 SW_PLUM    = vec3(0.251, 0.153, 0.318); // #402751  dark plum
const vec3 SW_PINK    = vec3(0.776, 0.318, 0.592); // #c65197  bright pink
const vec3 SW_BLOSSOM = vec3(0.875, 0.518, 0.647); // #df84a5  pale blossom

// Petrol/oil sheen ramp. A 0..1 phase sweeps through the COOL half of the palette
// (plum -> deep -> blue -> sky -> aqua-cyan -> green). This replaces a full-spectrum HSV rainbow:
// the thin-film shimmer still shifts hue like real oil, but every stop is an Apollo colour, so the
// slick reads iridescent without a garish neon rainbow.
vec3 sw_petrol(float t) {
	t = fract(t) * 5.0;                       // 6 colour stops -> 5 lerp segments
	if (t < 1.0) return mix(SW_PLUM, SW_DEEP, t);
	if (t < 2.0) return mix(SW_DEEP, SW_BLUE, t - 1.0);
	if (t < 3.0) return mix(SW_BLUE, SW_SKY,  t - 2.0);
	if (t < 4.0) return mix(SW_SKY,  SW_CYAN, t - 3.0);
	return mix(SW_CYAN, SW_GREEN, t - 4.0);
}

// Fire ramp for the burning wordmark. heat 0..1 climbs rose -> coral -> gold -> foam: the classic
// ember->orange->yellow->white blaze, but each stop is an Apollo colour.
vec3 sw_fire(float heat) {
	vec3 c = mix(SW_ROSE, SW_CORAL, smoothstep(0.10, 0.50, heat));
	c = mix(c, SW_GOLD, smoothstep(0.50, 0.80, heat));
	c = mix(c, SW_FOAM, smoothstep(0.82, 1.00, heat));
	return c;
}

#endif
