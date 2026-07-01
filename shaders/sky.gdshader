shader_type canvas_item;
// Vertical gradient "sky" for a fixed background ColorRect
// UV.y runs 0 at the top of the rect to 1 at the bottom, so we just
// blend three colors down the screen: deep sky -> horizon glow -> low haze.

uniform vec4 col_top : source_color = vec4(0.05, 0.07, 0.16, 1.0); // deep indigo overhead
uniform vec4 col_horizon : source_color = vec4(0.18, 0.34, 0.4, 1.0); // teal glow at the horizon
uniform vec4 col_bottom : source_color = vec4(0.30, 0.26, 0.4, 1.0); // warm purple haze low
uniform float horizon : hint_range(0.0, 1.0) = 0.60; // where the glow band sits (0=top, 1=bottom)

void fragment() {
	float y = UV.y;
	vec3 c;
	if (y < horizon) {
			// top half: indigo fading down into the horizon glow
			c = mix(col_top.rgb, col_horizon.rgb, y / horizon);
	} else {
			// bottom half: horizon glow fading into the low haze
			c = mix(col_horizon.rgb, col_bottom.rgb, (y - horizon) / (1.0 - horizon));
	}
	COLOR = vec4(c, 1.0);
}