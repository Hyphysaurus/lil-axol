shader_type canvas_item;
// Vertical gradient "sky" for the fixed background ColorRect, plus ambience: twinkling stars
// that fade in at night, softly drifting haze wisps for depth, and a gentle breathing shimmer
// along the horizon. UV.y runs 0 (top) -> 1 (bottom). The three colours + horizon are driven
// by day_night.gd, so the ambience (which keys off how dark the upper sky is) follows the cycle.

uniform vec4 col_top : source_color = vec4(0.05, 0.07, 0.16, 1.0);      // deep indigo overhead
uniform vec4 col_horizon : source_color = vec4(0.18, 0.34, 0.4, 1.0);   // teal glow at the horizon
uniform vec4 col_bottom : source_color = vec4(0.30, 0.26, 0.4, 1.0);    // warm purple haze low
uniform float horizon : hint_range(0.0, 1.0) = 0.60;                    // where the glow band sits

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
	return v;
}

void fragment() {
	float y = UV.y;
	vec3 c;
	if (y < horizon) {
		c = mix(col_top.rgb, col_horizon.rgb, y / horizon);          // indigo -> horizon glow
	} else {
		c = mix(col_horizon.rgb, col_bottom.rgb, (y - horizon) / (1.0 - horizon)); // glow -> haze
	}

	// how dark the upper sky is right now -> how strongly the night ambience shows
	float night = clamp(1.0 - dot(col_top.rgb, vec3(0.4)), 0.0, 1.0);

	// twinkling stars in the upper sky: sparse points, each with its own shimmer, fading below
	vec2 cell = floor(UV * vec2(90.0, 60.0));
	float star = step(0.986, hash(cell));
	float twinkle = 0.5 + 0.5 * sin(TIME * 3.0 + hash(cell) * 40.0);
	c += star * twinkle * smoothstep(horizon, 0.0, y) * night * 0.85;

	// softly drifting haze wisps — barely-there depth, doesn't fight the separate cloud layer
	c += (fbm(UV * vec2(3.0, 2.0) + vec2(TIME * 0.01, 0.0)) - 0.5) * 0.03;

	// a gentle breathing shimmer right along the horizon band
	float shimmer = smoothstep(0.12, 0.0, abs(y - horizon)) * (0.5 + 0.5 * sin(TIME * 0.5));
	c += col_horizon.rgb * shimmer * 0.06;

	COLOR = vec4(c, 1.0);
}
