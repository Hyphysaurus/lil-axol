shader_type canvas_item;
// A glossy oil blob floating on the water. `amount` 1.0 = full slick, 0.0 = cleaned
// (shrinks + fades out). Drawn on a white Sprite2D; squashed ellipse with an
// iridescent purple sheen swirl.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 oil_dark : source_color = vec4(0.04, 0.03, 0.06, 1.0);
uniform vec4 sheen : source_color = vec4(0.35, 0.14, 0.46, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 1.7);          // squash -> flat ellipse on the water
	float d = length(p);
	float r = 0.5 * (0.35 + 0.65 * amount);         // blob shrinks as it is cleaned
	float blob = smoothstep(r, r - 0.10, d);
	// iridescent sheen swirl
	float sw = sin(UV.x * 17.0 + TIME * 0.5) * sin(UV.y * 13.0 - TIME * 0.4);
	vec3 c = mix(oil_dark.rgb, sheen.rgb, clamp(sw * 0.5 + 0.35, 0.0, 0.6));
	COLOR = vec4(c, blob * amount);
}
