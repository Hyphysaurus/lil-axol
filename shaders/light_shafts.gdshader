shader_type canvas_item;
render_mode blend_add;
#include "res://shaders/apollo.gdshaderinc"
// Soft god-rays raking down through the water column. Additive (blend_add) so they brighten the
// water rather than paint over it; brightest just under the surface and fading with depth, drifting
// slowly sideways. A few overlapping sine bands at different frequencies make the shafts irregular
// (not a barcode). Drawn on a white Sprite2D scaled to the water rect; cove_life fades it in via
// modulate.a as the cove heals, so the sunlight only returns once the water clears.

uniform float intensity : hint_range(0.0, 1.0) = 0.55;
uniform float ray_tilt = 0.40;     // diagonal slant — beams lean as they descend
uniform float drift = 0.045;       // slow sideways drift speed

void fragment() {
	// slanted coordinate: the beams rake diagonally across the column and drift over time
	float s = UV.x + UV.y * ray_tilt + TIME * drift;
	// two sine bands at different frequencies -> irregular, natural-looking shafts. This runs
	// FULLSCREEN every frame once the cove is restored, so it's kept to two bands (a third finer band
	// was dropped for perf — the difference reads as a touch less filigree, not a different effect).
	float rays = smoothstep(0.55, 1.0, sin(s * 17.0) * 0.5 + 0.5);
	rays += 0.6 * smoothstep(0.70, 1.0, sin(s * 31.0 + 1.7) * 0.5 + 0.5);
	rays *= 0.6;
	// brightest up near the sun (screen top, UV.y = 0) and fading down, but only PARTWAY so the
	// shafts still rake through the water lower on screen — not just the sky. Soft L/R edge fade.
	float depth_fade = 1.0 - 0.7 * smoothstep(0.0, 1.05, UV.y);
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float a = rays * depth_fade * edge * intensity;
	vec3 col = mix(SW_CYAN, SW_FOAM, 0.55);   // pale sunlit water, on-palette
	COLOR = vec4(col, a);
}
