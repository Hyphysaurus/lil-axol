shader_type canvas_item;
#include "res://shaders/sweetie16.gdshaderinc"
// Tiny procedural fish: ellipse body + triangular tail + eye. Faces +x (flip_h for -x).
// Drawn on a small white Sprite2D; per-fish colour via the body_col / fin_col uniforms
// (cove_life sets these from the shared palette). Defaults + the eye are on-palette too.

uniform vec4 body_col : source_color = vec4(0.937, 0.490, 0.341, 1.0);   // SW_CORAL
uniform vec4 fin_col : source_color = vec4(0.694, 0.243, 0.325, 1.0);    // SW_ROSE
// per-fish fade for the local reveal (modulate can't reach a shader that writes COLOR)
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	// body — a front-heavy ellipse
	float body = 1.0 - smoothstep(0.30, 0.34, length(p * vec2(1.15, 2.3)));
	// tail — a triangle behind the body, widening toward the back
	float tail = 0.0;
	float txw = (-0.15 - p.x) / 0.30;                 // 0 at x=-0.15 -> 1 at x=-0.45
	if (p.x < -0.15 && txw <= 1.0) {
		tail = step(abs(p.y), mix(0.02, 0.26, clamp(txw, 0.0, 1.0)));
	}
	float a = max(body, tail);
	vec3 c = mix(fin_col.rgb, body_col.rgb, body);
	// eye near the front (SW_INK — the palette's darkest, so it reads as a dark dot)
	if (length(p - vec2(0.24, -0.04)) < 0.045) c = SW_INK;
	COLOR = vec4(c, a * reveal);
}
