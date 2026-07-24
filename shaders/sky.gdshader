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

	// twinkling stars in the upper sky: sparse POINTS (2026-07-24 pixel-fit: a star used to fill
	// its whole 7x6-cell on the effect grid and showed from mid-afternoon — they read as floating
	// grey blocks; now a 2px point in the cell centre, gated to genuine night only)
	vec2 sgrid = UV * vec2(90.0, 60.0);
	vec2 cell = floor(sgrid);
	vec2 cf = fract(sgrid);
	float star = step(0.986, hash(cell)) * step(abs(cf.x - 0.5), 0.16) * step(abs(cf.y - 0.5), 0.16);
	float twinkle = 0.5 + 0.5 * sin(TIME * 3.0 + hash(cell) * 40.0);
	float night_gate = smoothstep(0.72, 0.92, night);
	c += star * twinkle * smoothstep(horizon, 0.0, y) * night_gate * 0.85;

	// (the old fbm haze wisps are gone — 2026-07-24 perf pass: 4 noise octaves per fullscreen
	// pixel for a "barely-there" effect was the sky's whole budget on phone GPUs)

	// a gentle breathing shimmer right along the horizon band
	float shimmer = smoothstep(0.12, 0.0, abs(y - horizon)) * (0.5 + 0.5 * sin(TIME * 0.5));
	c += col_horizon.rgb * shimmer * 0.06;

	COLOR = vec4(c, 1.0);
}
