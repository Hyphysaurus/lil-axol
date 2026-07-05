shader_type canvas_item;
#include "res://shaders/apollo.gdshaderinc"
// Burning-text effect for a Label/RichTextLabel. It keeps the glyph SHAPE (from the font
// texture's alpha) but recolours it with a live fire gradient — hot at the base, cooling to
// yellow-white up top — and adds rising flame noise + a flicker, so the wordmark reads as if
// it's ablaze against the sky. Put a ShaderMaterial with this shader on the Label's `material`.
// `TEXTURE` is the font glyph, so we only paint where the letters are (t.a).
// The blaze palette is the shared sw_fire() ramp (rose->coral->gold->foam) so the wordmark burns
// in Sweetie 16 colours, matching the rest of the game.

uniform float speed = 1.0;        // how fast the flames lick upward
uniform float intensity = 1.0;    // 0 = tame embers, 1 = full blaze

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
	return v;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	// flame noise scrolling UP (subtract TIME on Y) — the moving tongues of fire
	float n = fbm(UV * vec2(7.0, 11.0) + vec2(0.0, -TIME * speed * 1.6));
	// heat rises: hotter toward the bottom of each glyph (UV.y = 1), plus the noise
	float heat = clamp((UV.y * 1.3) + n * 0.55 - 0.25, 0.0, 1.0) * intensity;
	// Sweetie 16 fire ramp: rose -> coral -> gold -> foam (see sw_fire in the palette include)
	vec3 fire = sw_fire(heat);
	// candle-like flicker so it never sits still
	fire *= 0.86 + 0.14 * sin(TIME * 11.0 + UV.x * 24.0);
	COLOR = vec4(fire, t.a) * COLOR;
}
