shader_type canvas_item;
// Full-screen post-process: samples the rendered frame and adds film grain, a vignette,
// and a gentle warm/mid-lift grade — the "de-flatten" pass that lifts the scene out of
// flat CSS-gradient territory into something painterly. Sits on the top CanvasLayer.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float grain : hint_range(0.0, 0.15) = 0.035;
uniform float vignette : hint_range(0.0, 1.0) = 0.40;
uniform float warm : hint_range(0.0, 0.1) = 0.03;
uniform float mid_lift : hint_range(0.85, 1.05) = 0.96;   // <1 lifts midtones

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	// vignette — darken toward the corners to frame the scene
	float d = distance(SCREEN_UV, vec2(0.5));
	c *= 1.0 - vignette * pow(clamp(d * 1.35, 0.0, 1.0), 2.2);
	// animated film grain to break up flat gradients
	float g = hash(SCREEN_UV * vec2(1280.0, 720.0) + fract(TIME) * 97.13) - 0.5;
	c += g * grain;
	// gentle grade: lift mids + a touch of warmth
	c = pow(clamp(c, 0.0, 1.0), vec3(mid_lift));
	c *= vec3(1.0 + warm, 1.0, 1.0 - warm * 0.5);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
