shader_type canvas_item;
// Expanding "clear water" ring for the oil-cleared pop. `t` (0->1, tweened by oil_spill.gd)
// grows the ring outward, thins it, and fades it out. Drawn on a small white Sprite2D.

uniform vec4 ring_col : source_color = vec4(0.85, 0.97, 1.0, 0.9);
uniform float t : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float r = mix(0.06, 0.48, t);          // radius grows with t
	float w = mix(0.12, 0.03, t);          // ring thins as it expands
	float outer = smoothstep(r + 0.02, r, d);
	float inner = smoothstep(r - w + 0.02, r - w, d);
	float ring = clamp(outer - inner, 0.0, 1.0);
	COLOR = vec4(ring_col.rgb, ring * ring_col.a * (1.0 - t));   // fade over life
}
