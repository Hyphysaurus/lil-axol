shader_type canvas_item;
// Flat-bottom cumulus on a horizon band (two depth layers), top-lit with shadowed
// bellies. light_col / shadow_col are driven by the day/night cycle so the clouds glow
// gold at dusk and silhouette at night. Output alpha = density -> the sky shows through.

uniform vec4 light_col : source_color = vec4(1.0, 0.99, 0.95, 1.0);   // sunlit tops (TimeOfDay)
uniform vec4 shadow_col : source_color = vec4(0.50, 0.60, 0.80, 1.0); // shaded bellies (TimeOfDay)
uniform float base_y : hint_range(0.3, 0.9) = 0.60;    // screen height the bank sits on
uniform float height : hint_range(0.05, 0.5) = 0.34;   // how tall the near bank rises
uniform float puffiness : hint_range(0.0, 0.9) = 0.55; // internal erosion -> separates puffs
uniform float coverage : hint_range(0.5, 1.6) = 1.35;  // taller / more cloud as this rises
uniform float drift = 0.04;                            // wind speed
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// billow fbm: |2n-1| per octave -> rounded puffy lumps (not smooth haze)
float bfbm(vec2 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < oct; i++) {
		v += a * abs(2.0 * vnoise(p) - 1.0);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// vec2(alpha, depth): depth 0 at the lit top edge -> 1 at the shaded base
vec2 cumulus(vec2 uv, float scale, float by, float h, float dx) {
	float ux = uv.x * scale + dx;
	float topn = clamp(bfbm(vec2(ux, 2.3), 4) * coverage, 0.0, 1.0);
	// break the bank into separate masses so it isn't a continuous wall along the horizon
	float gap = smoothstep(0.22, 0.55, vnoise(vec2(ux * 0.5, 4.0)));
	topn *= gap;
	// undulate the underside per column so the bottom is not one ruler-straight horizon line
	float wob = (vnoise(vec2(ux * 0.6, 11.0)) - 0.5) * 0.07;
	float bb = by + wob;
	float cloud_top = bb - h * topn;
	float flat_bottom = clamp((bb - uv.y) / 0.05, 0.0, 1.0);   // softer, feathered belly
	float soft_top = clamp((uv.y - cloud_top) / 0.035, 0.0, 1.0);
	float det = bfbm(vec2(ux * 2.1, uv.y * scale * 1.6 + 5.0), 3);
	float alpha = clamp(soft_top * flat_bottom * (1.0 - puffiness * det), 0.0, 1.0);
	float depth = clamp((uv.y - cloud_top) / max(bb - cloud_top, 0.001), 0.0, 1.0);
	return vec2(alpha, depth);
}

vec4 shade(vec2 ad) {
	float bright = pow(1.0 - ad.y, 0.8);
	return vec4(mix(shadow_col.rgb, light_col.rgb, bright), ad.x);
}

void fragment() {
	// The cloud band only occupies a horizontal strip around base_y. Skip ALL the noise for pixels
	// above the highest possible top / below the lowest belly (guaranteed empty) — roughly half the
	// screen, the cheapest big win on this fullscreen pass. Gated by an if (no return in fragment())
	// and the strip is screen-space coherent, so the GPU branch stays cheap.
	COLOR = vec4(0.0);
	if (UV.y >= base_y - height - 0.06 && UV.y <= base_y + 0.12) {
		vec4 far = shade(cumulus(UV, 6.0, base_y - 0.10, height * 0.5, TIME * drift * 0.6 + 37.0));
		far.a *= 0.8;
		vec4 near = shade(cumulus(UV, 3.4, base_y, height, TIME * drift));
		float outa = near.a + far.a * (1.0 - near.a);
		vec3 outrgb = (near.rgb * near.a + far.rgb * far.a * (1.0 - near.a)) / max(outa, 0.001);
		COLOR = vec4(outrgb, outa * opacity);
	}
}
