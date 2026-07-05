shader_type canvas_item;
// Block-tile land, drawn on ONE quad instead of thousands of draw_rects. The 8px voxel look —
// per-cell warm-loam tone, a wet gradient below the waterline, oil-staining while polluted, soft
// warm seams and scattered grit — is all computed on the GPU here. `oil` (1 = fully stained, 0 =
// clean) is the only thing that changes at runtime, so the soil costs a single cheap draw call.
#include "res://shaders/apollo.gdshaderinc"

uniform float oil : hint_range(0.0, 1.0) = 1.0;   // 1 - cleanliness
uniform vec2 grid = vec2(32.0, 35.0);             // cell columns / rows
uniform float surface_row = 3.0;                  // rows above this are dry; below reads submerged

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * grid);
	vec2 f = fract(UV * grid);
	float j = hash(cell);
	float j2 = hash(cell.yx + 11.7);
	float depth = cell.y / grid.y;                  // 0 top .. 1 bottom

	// DISTINCT STRATA — a soil cross-section: warm topsoil -> loam -> clay -> stony bedrock, each
	// band varied per cell and with a per-column wobble so the boundaries aren't ruler-straight
	float sd = depth + (hash(vec2(cell.x, 3.0)) - 0.5) * 0.05;
	vec3 tone;
	if      (sd < 0.22) tone = mix(SW_CLAY, SW_AMBER, 0.40 * j);   // warm topsoil under the grass
	else if (sd < 0.46) tone = mix(SW_LOAM, SW_CLAY, 0.50 * j);    // loam
	else if (sd < 0.72) tone = mix(SW_SOIL, SW_LOAM, 0.55 * j);    // clay / subsoil
	else                tone = mix(SW_SOIL, SW_STEEL, 0.30 + 0.35 * j);  // stony bedrock

	// embedded grey stones — occasional rock cells, commoner deeper down
	float stone = hash(cell.yx + 5.3);
	if (stone < 0.10 + depth * 0.22)
		tone = mix(tone, mix(SW_STEEL, SW_SLATE, hash(cell + 2.2)), 0.55);
	// sandy pockets — an occasional pale cell breaks up the brown
	if (j2 > 0.9)
		tone = mix(tone, SW_SAND, 0.40);

	// wetter/darker below the waterline, then oil-stained while polluted
	float wet = clamp((cell.y - surface_row) / max(1.0, grid.y - surface_row), 0.0, 1.0);
	tone = mix(tone, SW_SOIL, wet * 0.45);
	tone = mix(tone, SW_INK, oil * 0.55);

	// intra-cell mottling (sub-cell noise) — grain within each block instead of a flat fill
	float mott = hash(floor(UV * grid * 3.0) + 0.5);
	tone *= 0.9 + 0.2 * mott;

	// soft warm seam at the block borders (SOIL, not near-black) — reads as blocks, no harsh grid
	float seam = max(max(step(f.x, 0.07), step(0.93, f.x)), max(step(f.y, 0.07), step(0.93, f.y)));
	tone = mix(tone, SW_SOIL, seam * 0.14);

	// scattered grit specks
	float s = hash(cell.yx + 3.1);
	if (s > 0.6) {
		vec2 sp = vec2(0.2 + s * 0.5, 0.2 + hash(cell.xy + 7.7) * 0.5);
		float d = distance(f, sp);
		vec3 grit = mix(s > 0.83 ? SW_SOIL : SW_SAND, tone, 0.30);
		tone = mix(tone, grit, (1.0 - smoothstep(0.05, 0.12, d)) * 0.6);
	}

	COLOR = vec4(tone, 1.0);
}
