shader_type canvas_item;
render_mode unshaded;
// Slice-3 global palette pass (spec 2026-07-23): runs LAST inside the 320x180 world viewport,
// snapping every pixel — procedural gradients, day/night Mood tints, god-rays, grain, iris —
// to its nearest Apollo swatch, with an ordered Bayer 4x4 dither between the two nearest
// swatches so gradients keep depth as retro texture. Sprites are already Apollo-authored, so
// the snap is a near-no-op for them. dither_strength 0 = hard posterize.
#include "res://shaders/apollo.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool enabled = true;

const int PAL_N = 29;
const vec3 PAL[PAL_N] = vec3[](
	SW_INK, SW_SLATE, SW_STEEL, SW_MIST, SW_FOAM,
	SW_AQUA, SW_CYAN, SW_SKY, SW_BLUE, SW_DEEP, SW_ABYSS, SW_TEAL,
	SW_MOSS, SW_GREEN, SW_FERN, SW_LEAF, SW_SPROUT,
	SW_SOIL, SW_LOAM, SW_CLAY, SW_SAND,
	SW_EMBER, SW_AMBER, SW_GOLD,
	SW_ROSE, SW_CORAL, SW_PLUM, SW_PINK, SW_BLOSSOM
);

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	if (!enabled) {
		COLOR = vec4(src, 1.0);
	} else {
		float d1 = 1e9; float d2 = 1e9;
		vec3 c1 = src; vec3 c2 = src;
		for (int i = 0; i < PAL_N; i++) {
			vec3 dv = PAL[i] - src;
			float d = dot(dv, dv);
			if (d < d1)      { d2 = d1; c2 = c1; d1 = d; c1 = PAL[i]; }
			else if (d < d2) { d2 = d;  c2 = PAL[i]; }
		}
		// how far src sits from its nearest swatch toward the runner-up (0 = exactly on c1)
		float t = sqrt(d1) / max(sqrt(d1) + sqrt(d2), 1e-5);
		ivec2 px = ivec2(FRAGCOORD.xy);
		float th = (BAYER[(px.y % 4) * 4 + (px.x % 4)] + 0.5) / 16.0;
		COLOR = vec4(th < (t * 2.0 * dither_strength) ? c2 : c1, 1.0);
	}
}
