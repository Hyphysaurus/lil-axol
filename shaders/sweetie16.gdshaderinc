// Sweetie 16 palette (GrafxKid, lospec.com/palette-list/sweetie-16) — the game's master colour
// set. Included by the procedural shaders so every generated visual snaps to the SAME 16 colours.
// Values are the raw hex normalised to 0..1: the Compatibility renderer is sRGB end-to-end (no
// linear conversion), so these floats land on-screen exactly as the hex codes.
//
// ONE SOURCE OF TRUTH (shader side): edit a colour here and every shader that `#include`s this
// file updates at once. The GDScript mirror lives in game/palette.gd — keep the two in step.

#ifndef SWEETIE16_INC
#define SWEETIE16_INC

const vec3 SW_INK   = vec3(0.102, 0.110, 0.173); // #1a1c2c  darkest navy
const vec3 SW_SLATE = vec3(0.200, 0.235, 0.341); // #333c57  dark slate
const vec3 SW_STEEL = vec3(0.337, 0.424, 0.525); // #566c86  steel grey-blue
const vec3 SW_MIST  = vec3(0.580, 0.690, 0.761); // #94b0c2  pale mist
const vec3 SW_FOAM  = vec3(0.957, 0.957, 0.957); // #f4f4f4  near-white
const vec3 SW_CYAN  = vec3(0.451, 0.937, 0.969); // #73eff7  bright cyan
const vec3 SW_SKY   = vec3(0.255, 0.651, 0.965); // #41a6f6  sky blue
const vec3 SW_BLUE  = vec3(0.231, 0.365, 0.788); // #3b5dc9  royal blue
const vec3 SW_DEEP  = vec3(0.161, 0.212, 0.435); // #29366f  deep blue
const vec3 SW_TEAL  = vec3(0.145, 0.443, 0.475); // #257179  dark teal
const vec3 SW_GREEN = vec3(0.220, 0.718, 0.392); // #38b764  green
const vec3 SW_LEAF  = vec3(0.655, 0.941, 0.439); // #a7f070  light leaf-green
const vec3 SW_GOLD  = vec3(1.000, 0.804, 0.459); // #ffcd75  warm gold
const vec3 SW_CORAL = vec3(0.937, 0.490, 0.341); // #ef7d57  coral/orange
const vec3 SW_ROSE  = vec3(0.694, 0.243, 0.325); // #b13e53  rose-red
const vec3 SW_PLUM  = vec3(0.365, 0.153, 0.365); // #5d275d  dark plum

// Petrol/oil sheen ramp. A 0..1 phase sweeps through the COOL half of the palette
// (plum -> deep -> blue -> teal -> cyan -> green). This replaces a full-spectrum HSV rainbow:
// the thin-film shimmer still shifts hue like real oil, but every stop is a Sweetie 16 colour,
// so the slick reads iridescent without the garish neon rainbow.
vec3 sw_petrol(float t) {
	t = fract(t) * 5.0;                       // 6 colour stops -> 5 lerp segments
	if (t < 1.0) return mix(SW_PLUM, SW_DEEP,  t);
	if (t < 2.0) return mix(SW_DEEP, SW_BLUE,  t - 1.0);
	if (t < 3.0) return mix(SW_BLUE, SW_TEAL,  t - 2.0);
	if (t < 4.0) return mix(SW_TEAL, SW_CYAN,  t - 3.0);
	return mix(SW_CYAN, SW_GREEN, t - 4.0);
}

// Fire ramp for the burning wordmark. heat 0..1 climbs rose -> coral -> gold -> foam: the
// classic ember->orange->yellow->white blaze, but each stop is a Sweetie 16 colour.
vec3 sw_fire(float heat) {
	vec3 c = mix(SW_ROSE, SW_CORAL, smoothstep(0.10, 0.50, heat));
	c = mix(c, SW_GOLD, smoothstep(0.50, 0.80, heat));
	c = mix(c, SW_FOAM, smoothstep(0.82, 1.00, heat));
	return c;
}

#endif
