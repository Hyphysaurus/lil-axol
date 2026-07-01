shader_type canvas_item;
// Procedural grass blades on a strip. The strip's bottom (UV.y = 1) is the ground line;
// blades rise upward and sway with wind (stronger toward the tips). Transparent between
// blades so the scene shows through. Lives in the world layer, so the Mood CanvasModulate
// tints it with the day/night cycle automatically.

uniform vec4 base_col : source_color = vec4(0.16, 0.40, 0.18, 1.0); // blade base (dark)
uniform vec4 tip_col : source_color = vec4(0.48, 0.74, 0.34, 1.0);  // blade tip (light)
uniform float blades = 64.0;        // blades across the strip width
uniform float wind = 0.05;          // sway amplitude (UV units)
uniform float wind_speed = 1.4;
uniform float height : hint_range(0.2, 1.0) = 0.9; // max blade height (fraction of strip)

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	float i = floor(UV.x * blades);
	float r = hash(i + 1.0);
	float cx = (i + 0.5) / blades;            // this blade's base x
	float bh = height * (0.55 + 0.45 * r);    // this blade's height
	float g = 1.0 - UV.y;                      // 0 at ground .. 1 at strip top
	float gn = clamp(g / max(bh, 0.001), 0.0, 1.0); // 0 base .. 1 tip along this blade
	float sway = sin(TIME * wind_speed + i * 1.7) * wind * gn * gn;
	float bx = cx + sway;
	float hw = (0.5 / blades) * (0.95 - 0.65 * gn); // taper toward the tip
	float inside = step(g, bh) * step(abs(UV.x - bx), hw);
	vec3 c = mix(base_col.rgb, tip_col.rgb, gn);
	COLOR = vec4(c, inside);
}
