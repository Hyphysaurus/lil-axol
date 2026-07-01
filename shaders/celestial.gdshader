shader_type canvas_item;
// Sun by day, moon by night: a soft glowing disc that arcs across the sky with the
// day/night clock (positions/visibility set from day_night.gd). Drawn on a full-rect
// ColorRect inside SkyLayer, BEHIND the clouds, so the clouds drift in front of it.

uniform vec2 sun_uv = vec2(0.5, 0.25);
uniform vec2 moon_uv = vec2(0.5, 1.5);
uniform vec4 sun_col : source_color = vec4(1.0, 0.93, 0.70, 1.0);
uniform vec4 moon_col : source_color = vec4(0.82, 0.90, 1.0, 1.0);
uniform float sun_vis = 1.0;
uniform float moon_vis = 0.0;
uniform float radius : hint_range(0.005, 0.15) = 0.04;
uniform float glow : hint_range(1.0, 12.0) = 6.0;
uniform float aspect = 1.7777;

vec2 body(vec2 uv, vec2 c, float r) {
	vec2 d = uv - c;
	d.x *= aspect;                         // keep the disc circular on a wide screen
	float dist = length(d);
	float core = smoothstep(r, r * 0.8, dist);
	float halo = pow(clamp(1.0 - dist / (r * glow), 0.0, 1.0), 2.2);
	return vec2(core, halo);
}

void fragment() {
	vec2 s = body(UV, sun_uv, radius) * sun_vis;
	vec2 m = body(UV, moon_uv, radius) * moon_vis;
	vec3 col = sun_col.rgb * (s.x + s.y * 0.5) + moon_col.rgb * (m.x + m.y * 0.5);
	float a = clamp(s.x + s.y * 0.5 + m.x + m.y * 0.5, 0.0, 1.0);
	COLOR = vec4(col, a);
}
