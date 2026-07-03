shader_type canvas_item;
// Sandy bank on the cove's left edge. Warm dry sand up top rolls (via dune undulation) into
// cooler, damp, shadowed sand lower down, with fine grain, faint tide lines, and an
// atmospheric haze along the top edge so the bank recedes into the sky instead of ending in
// a hard flat wall. Drawn on a Sprite2D over the beach rect; lives in the world layer so the
// Mood CanvasModulate tints it with the day/night cycle.

uniform vec4 sand_top : source_color = vec4(0.91, 0.85, 0.71, 1.0); // sunlit dry sand
uniform vec4 sand_low : source_color = vec4(0.52, 0.46, 0.42, 1.0); // cool damp shadowed base
uniform vec4 sand_mid : source_color = vec4(0.75, 0.64, 0.49, 1.0); // the roll between
uniform vec4 haze : source_color = vec4(0.80, 0.74, 0.78, 1.0);     // atmospheric top tint
uniform float grain : hint_range(0.0, 0.25) = 0.08;
// oiled state: 1 = spill-washed beach — dimmed sand with dark horizontal oil streaks.
// Healed toward 0 by ShoreHealth as the cove is cleaned.
uniform float sludge : hint_range(0.0, 1.0) = 0.0;

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
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// rolling dunes: a low-frequency swell warps the depth line so light and shadow undulate
	// across the bank instead of a dead-flat gradient
	float dune = fbm(vec2(UV.x * 2.6, UV.y * 1.4 + 5.0));
	float depth = clamp(UV.y + (dune - 0.5) * 0.26, 0.0, 1.0);
	// dry warm sand near the top -> mid -> cool damp shadow at the base
	vec3 c = mix(sand_top.rgb, sand_mid.rgb, smoothstep(0.0, 0.45, depth));
	c = mix(c, sand_low.rgb, smoothstep(0.4, 1.0, depth));
	// fine grain + sparse dark speckle
	c += (fbm(UV * vec2(85.0, 110.0)) - 0.5) * grain;
	c -= step(0.85, fbm(UV * vec2(190.0, 210.0) + 7.0)) * 0.05;
	// faint tide lines drifting through the upper-mid, where the bank meets the water
	float tide = sin(depth * 40.0 + fbm(UV * vec2(5.0, 2.0)) * 6.0);
	c += smoothstep(0.88, 1.0, tide) * 0.045 * (1.0 - smoothstep(0.15, 0.6, UV.y));
	// warm sun catch along the crest, cool damp sheen deep down
	c += vec3(0.06, 0.04, 0.01) * (1.0 - smoothstep(0.0, 0.22, depth));
	c += vec3(0.0, 0.02, 0.05) * smoothstep(0.7, 1.0, depth);
	// atmospheric haze along the very top edge -> the bank recedes into the sky, no hard wall
	c = mix(c, haze.rgb, (1.0 - smoothstep(0.0, 0.16, UV.y)) * 0.55);
	// washed-up oil: horizontal streak bands + an overall grime dim, healing with the cove
	float streak = smoothstep(0.55, 0.85, fbm(UV * vec2(26.0, 9.0) + 3.0));
	c = mix(c, c * vec3(0.32, 0.30, 0.27), sludge * streak * 0.9);
	c *= 1.0 - 0.15 * sludge;
	COLOR = vec4(c, 1.0);
}
