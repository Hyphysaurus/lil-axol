shader_type canvas_item;
// Textured, shaded sand for the beach — grain + speckle + vertical shading so it reads as
// a sandy bank instead of a flat beige block. Drawn on a Sprite2D over the beach rect;
// lives in the world layer so the Mood CanvasModulate tints it with the day/night cycle.

uniform vec4 sand_top : source_color = vec4(0.91, 0.85, 0.71, 1.0); // sunlit surface
uniform vec4 sand_low : source_color = vec4(0.58, 0.50, 0.39, 1.0); // shaded depth
uniform float grain : hint_range(0.0, 0.25) = 0.11;

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
	vec3 c = mix(sand_top.rgb, sand_low.rgb, smoothstep(0.0, 0.55, UV.y)); // lit top -> shaded base
	c += (fbm(UV * vec2(70.0, 90.0)) - 0.5) * grain;                        // sand grain
	float speck = step(0.82, fbm(UV * vec2(180.0, 200.0) + 7.0));
	c -= speck * 0.06;                                                       // dark speckle
	// a lighter dune highlight rolling across the top surface
	c += (1.0 - smoothstep(0.0, 0.18, UV.y)) * 0.05;
	COLOR = vec4(c, 1.0);
}
