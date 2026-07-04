shader_type canvas_item;
// The earthen bank on the cove's left edge. Dry topsoil up top rolls (via dune undulation)
// into darker, damp, shadowed soil below, textured with mottled clods, grain and pebbles so it
// reads as real dirt rather than a flat wall. Its top edge tucks into dark topsoil under the
// grass. When polluted, OIL SEEPS DOWN into the earth from the surface in irregular fingers.
// Drawn on a Sprite2D over the beach rect; lives in the world layer so the Mood CanvasModulate
// tints it with the day/night cycle.

uniform vec4 sand_top : source_color = vec4(0.78, 0.70, 0.55, 1.0); // dry sunlit topsoil
uniform vec4 sand_low : source_color = vec4(0.40, 0.35, 0.31, 1.0); // dark damp soil, deep down
uniform vec4 sand_mid : source_color = vec4(0.60, 0.51, 0.39, 1.0); // the roll between
uniform vec4 haze : source_color = vec4(0.30, 0.26, 0.22, 1.0);     // dark topsoil under the grass
uniform float grain : hint_range(0.0, 0.25) = 0.08;
// oiled state: 1 = freshly spilled, 0 = clean. Drives how far crude has soaked into the earth.
// Eased toward (1 - cleanliness) by ShoreHealth as the cove is restored.
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
	// dry topsoil near the top -> mid -> dark damp soil at the base
	vec3 c = mix(sand_top.rgb, sand_mid.rgb, smoothstep(0.0, 0.45, depth));
	c = mix(c, sand_low.rgb, smoothstep(0.4, 1.0, depth));
	// mottled clods: low-frequency dark/light blotches break the gradient so it reads as earth
	float clod = fbm(UV * vec2(9.0, 7.0) + 3.0);
	c *= 0.85 + 0.20 * clod;
	// broad loam patches (very low frequency) layer earthy tonal richness under the clods
	float loam = fbm(UV * vec2(3.4, 2.6) + 11.0);
	c *= 0.90 + 0.16 * loam;
	// fine grain + sparse dark pebbles + a few pale grit flecks that catch the light
	c += (fbm(UV * vec2(85.0, 110.0)) - 0.5) * grain;
	c -= step(0.86, fbm(UV * vec2(190.0, 210.0) + 7.0)) * 0.05;
	c += step(0.90, fbm(UV * vec2(150.0, 175.0) + 21.0)) * 0.045;
	// cool damp sheen deep down
	c += vec3(0.0, 0.02, 0.05) * smoothstep(0.7, 1.0, depth);
	// tuck the very top edge into dark topsoil so it blends under the grass, not a hard line
	c = mix(c, haze.rgb, (1.0 - smoothstep(0.0, 0.14, UV.y)) * 0.7);
	// a damp mossy band right beneath the grass line so the bank reads rooted & lush, not cut off
	vec3 moss = vec3(0.17, 0.26, 0.15);
	c = mix(c, moss, (1.0 - smoothstep(0.0, 0.09, UV.y)) * 0.4);

	// --- OIL SEEP ---------------------------------------------------------------------------
	// Crude soaks DOWNWARD into the earth from the surface (UV.y = 0). `front` is how deep it
	// has reached: it grows with `sludge`, and an fbm per column makes the soak line ragged, so
	// the oil bleeds in irregular fingers instead of a straight band. Above the front the earth
	// is oil-soaked (near-black, wet, faint glisten); below it the soil is still clean. When the
	// cove is fully restored (sludge -> 0) `front` -> 0 and no oil shows at all.
	float finger = fbm(vec2(UV.x * 6.0, 1.7));               // per-column soak depth (0..1)
	float front = sludge * (0.28 + 0.55 * finger);           // how far down the oil reaches
	float soak = (1.0 - smoothstep(front - 0.10, front, UV.y)) * sludge;
	vec3 oil = vec3(0.055, 0.05, 0.062);                     // near-black crude, faintly cool
	float glisten = smoothstep(0.6, 0.95, fbm(UV * vec2(7.0, 9.0))) * soak * 0.12; // wet sheen
	c = mix(c, oil, clamp(soak * 0.92, 0.0, 1.0));
	c += glisten;
	COLOR = vec4(c, 1.0);
}
