shader_type canvas_item;
// Cozy 2D ocean surface + volume. Drawn on a white 1x1 Sprite2D scaled to the
// water rectangle, so UV runs 0..1 across the region. rect_size (px) is set from
// world.gd so wave frequency/amplitude stay in world pixels (no stretching).

uniform vec2 rect_size = vec2(1160.0, 372.0);
// How many px of the sprite sit ABOVE the still waterline (room for wave crests).
uniform float overhang = 8.0;

uniform vec4 col_shallow : source_color = vec4(0.20, 0.58, 0.62, 0.38);
uniform vec4 col_deep    : source_color = vec4(0.04, 0.13, 0.34, 0.74);
uniform vec4 col_foam    : source_color = vec4(0.88, 0.97, 1.00, 0.95);

// restoration: 0 = oily/murky cove, 1 = clean water (driven by world.gd)
uniform float clean : hint_range(0.0, 1.0) = 1.0;
uniform vec4 col_oily_shallow : source_color = vec4(0.15, 0.20, 0.12, 0.62);
uniform vec4 col_oily_deep    : source_color = vec4(0.05, 0.06, 0.04, 0.86);

uniform float wave_amp = 4.0;        // px
uniform float wave_len = 90.0;       // px
uniform float wave_speed = 1.2;
uniform float foam_thickness = 2.5;  // px
uniform float caustic_strength = 0.10;

// sky reflection: clean water mirrors the sky just under the surface (oily water stays matte)
uniform vec4 sky_reflect : source_color = vec4(0.5, 0.62, 0.85, 1.0);  // colour set by day_night.gd
uniform float reflect_strength : hint_range(0.0, 1.0) = 0.35;
uniform float reflect_depth = 70.0;  // px the reflection fades over

void fragment() {
	float H = rect_size.y;
	float W = rect_size.x;
	float px_x = UV.x * W;
	float px_y = UV.y * H;            // 0 at sprite top
	float still = overhang;           // px from sprite top down to the still waterline

	// two-octave travelling surface wave -> px y of the surface in this column
	float w = sin(px_x / wave_len * 6.2831853 + TIME * wave_speed)
	        + 0.5 * sin(px_x / (wave_len * 0.45) * 6.2831853 - TIME * wave_speed * 1.7);
	float crest = still + w * wave_amp;

	if (px_y < crest) {
		COLOR = vec4(0.0);                       // air, above the wavy surface
	} else if (px_y < crest + foam_thickness) {
		COLOR = col_foam;                        // foam line
	} else {
		float depth = clamp((px_y - crest) / max(H - crest, 1.0), 0.0, 1.0);
		vec4 sc = mix(col_oily_shallow, col_shallow, clean);
		vec4 dc = mix(col_oily_deep, col_deep, clean);
		vec4 c = mix(sc, dc, depth);
		// scrolling caustic interference, fading with depth
		float ca = sin(px_x * 0.06 + TIME * 0.9) * sin(px_y * 0.05 - TIME * 0.6);
		c.rgb += ca * caustic_strength * (1.0 - depth);
		// gentle brighten just beneath the foam
		float band = smoothstep(crest + foam_thickness, crest + foam_thickness + 8.0, px_y);
		c.rgb += (1.0 - band) * 0.08;
		// sky reflection near the surface, fading with depth; gated by clean so oil stays matte
		float refl = 1.0 - smoothstep(0.0, reflect_depth, px_y - (crest + foam_thickness));
		c.rgb = mix(c.rgb, sky_reflect.rgb, refl * reflect_strength * clean);
		COLOR = c;
	}
}
