shader_type canvas_item;
// Tunnel-dark iris wipe for pathway crossings: ink darkness with a circular opening that shrinks
// (swimming INTO the tunnel) or grows (emerging on the other side), with a faint aqua rim at the
// opening's edge so it reads as water-in-a-dark-passage, not an abstract fade.
#include "res://shaders/apollo.gdshaderinc"

uniform float t : hint_range(0.0, 1.3) = 1.3;   // opening radius; 1.3 = fully open, 0 = swallowed

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // aspect-correct so the opening stays round
	float d = length(p);
	float dark = smoothstep(t - 0.07, t, d);            // 0 inside the opening, 1 in the tunnel dark
	float rim = smoothstep(t - 0.10, t - 0.05, d) * (1.0 - smoothstep(t - 0.03, t, d));
	vec3 col = mix(SW_INK, SW_AQUA, rim * 0.35);        // a faint watery ring at the mouth
	COLOR = vec4(col, dark);
}
