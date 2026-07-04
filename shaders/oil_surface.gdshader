shader_type canvas_item;
#include "res://shaders/sweetie16.gdshaderinc"
// Oil FILM on the water surface, driven by a coverage mask the player scrubs clean. Where the
// mask's red channel is high the surface is an iridescent oily slick; where you've sprayed it
// away it fades to transparent, revealing the clean water + sky reflection beneath. Drifting
// fbm gives the slick a lobed, slowly-swirling edge so it reads as part of the water surface,
// not a sprite sitting on top of it. The sheen uses the shared sw_petrol() ramp so the slick
// shimmers in on-palette Sweetie 16 tones instead of a full neon rainbow.

uniform sampler2D coverage : filter_linear;   // r = oil amount 0..1 across the water rect
uniform vec4 oil_dark : source_color = vec4(0.102, 0.110, 0.173, 1.0);   // SW_INK — on-palette core
uniform float sheen : hint_range(0.0, 1.0) = 0.7;   // iridescent sheen strength
uniform float swirl_speed = 0.12;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
	return v;
}

void fragment() {
	float cov = texture(coverage, UV).r;
	float t = TIME * swirl_speed;
	// organic lobed edge: perturb the coverage with drifting fbm so the slick boundary wobbles
	float n = fbm(UV * vec2(7.0, 12.0) + vec2(t, -t));
	float film = smoothstep(0.28, 0.55, cov + (n - 0.5) * 0.30);
	if (film < 0.004) {
		COLOR = vec4(0.0);
	} else {
		// iridescent thin-film petrol sheen, strongest toward the thinning (rim) of the slick
		float edge = 1.0 - smoothstep(0.35, 0.9, cov);
		float irid_h = fbm(UV * 5.0 + vec2(-t, t)) * 2.2 + cov * 1.4;
		vec3 irid = sw_petrol(irid_h);
		vec3 c = mix(oil_dark.rgb, irid, edge * sheen + 0.10);
		// faint glossy sway highlight
		c += 0.10 * smoothstep(0.6, 1.0, fbm(UV * 3.0 + vec2(t * 0.5)));
		// thick SLUDGE near the source reads dark & matte — the rainbow drains out of the
		// clotted core, so thin sheen (bright) vs thick sludge (dark) is legible at a glance
		float sludge_k = smoothstep(0.6, 0.95, cov);
		c = mix(c, oil_dark.rgb * 0.5, sludge_k * 0.75);
		COLOR = vec4(c, film * 0.94);
	}
}
