shader_type canvas_item;
// Blends the tiled reef backdrop into the water so it reads as environment, not a sticker.
// The top edge dissolves into the surrounding water (kills the hard band line), and the lower
// reef sinks toward a deep tint for atmospheric depth. Colour still receives the day/night
// CanvasModulate and the cleanliness reveal (modulate on the SeabedBackdrop node) on top.

uniform float top_fade : hint_range(0.0, 0.8) = 0.42;    // top fraction that melts into water
uniform float edge_fade : hint_range(0.0, 0.5) = 0.16;   // L/R fraction that crossfades into the neighbour tile
uniform float bottom_fade : hint_range(0.0, 0.6) = 0.30; // bottom fraction that merges into the floor
// depth_tint should match the Seabed floor polygon so the reef bottom blends seamlessly into it
uniform vec4 depth_tint : source_color = vec4(0.11, 0.16, 0.23, 1.0);
uniform float depth_amount : hint_range(0.0, 1.0) = 0.30; // how much the floor sinks into murk

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// dissolve the top edge into the water column (no hard upper line)
	c.a *= smoothstep(0.0, top_fade, UV.y);
	// feather the left/right edges so overlapping neighbour tiles crossfade (no vertical seam)
	c.a *= smoothstep(0.0, edge_fade, UV.x) * smoothstep(0.0, edge_fade, 1.0 - UV.x);
	// sink toward the deep tint with depth, and fully merge the bottom edge into the floor colour
	float bottom = smoothstep(1.0 - bottom_fade, 1.0, UV.y);
	c.rgb = mix(c.rgb, depth_tint.rgb, max(UV.y * depth_amount, bottom));
	COLOR = c;
}
