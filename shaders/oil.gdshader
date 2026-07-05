shader_type canvas_item;
#include "res://shaders/apollo.gdshaderinc"
// Oil slick floating on water: an organic lobed blob with a dark core, an iridescent thin-film
// sheen toward the rim, and a glossy highlight. The sheen slowly swirls. `amount` 1 = full slick,
// 0 = cleaned (the blob shrinks + fades out). The iridescence is the shared sw_petrol() ramp —
// an on-palette petrol shimmer (Sweetie 16 cool tones) rather than a full neon rainbow.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 oil_dark : source_color = vec4(0.102, 0.110, 0.173, 1.0);   // SW_INK — on-palette core
uniform float sheen : hint_range(0.0, 1.0) = 0.7;    // iridescent sheen strength
uniform float swirl_speed = 0.15;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 1.55);
	float t = TIME * swirl_speed;
	// organic lobed edge (noise-perturbed radius), shrinking as it's cleaned
	float n = fbm(UV * 3.2 + vec2(2.0));
	float d = length(p) + (n - 0.5) * 0.16;
	float rad = 0.46 * (0.4 + 0.6 * amount);
	float blob = smoothstep(rad, rad - 0.06, d);
	// iridescent thin-film petrol sheen, drifting slowly (on-palette, not a full rainbow)
	float film = fbm(vec2(UV.x * 5.0 + p.y * 2.0 + t, UV.y * 5.0 + p.x * 2.0 - t));
	vec3 irid = sw_petrol(film * 2.2 + d * 1.6);
	float edge = clamp((d - 0.15) / 0.32, 0.0, 1.0);       // rainbow stronger toward the rim
	vec3 dark = mix(oil_dark.rgb, oil_dark.rgb + vec3(0.05, 0.03, 0.06), clamp(d * 1.2, 0.0, 1.0));
	vec3 c = mix(dark, irid, edge * sheen + 0.12);
	// glossy specular highlight (upper-left)
	float gl = clamp((0.14 - length(p - vec2(-0.14, -0.20))) / 0.14, 0.0, 1.0);
	c += gl * 0.5;
	COLOR = vec4(c, blob * amount);
}
