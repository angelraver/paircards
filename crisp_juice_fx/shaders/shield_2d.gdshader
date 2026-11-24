// Crisp Juice Particles - shield (2D). Bubble shield with hex pattern, rim light and a moving sheen. progress pops it in.
// Driven by CrispFx2D: it sets `progress`. Tint it with the node's modulate (or the effect's `color`).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform vec4 color_rim : source_color = vec4(0.85, 1.0, 1.0, 1.0);
uniform float hex_scale : hint_range(1.0, 30.0) = 7.0;
uniform float hex_strength : hint_range(0.0, 1.0) = 0.4;
uniform float sweep_speed = 0.35;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.5;
float cj_hexdist(vec2 p) { p = abs(p); return max(dot(p, normalize(vec2(1.0, 1.732))), p.x); }
float cj_hexedge(vec2 p) {
	vec2 rr = vec2(1.0, 1.732);
	vec2 h = rr * 0.5;
	vec2 a = mod(p, rr) - h;
	vec2 b = mod(p - h, rr) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	return smoothstep(0.4, 0.49, cj_hexdist(g));
}

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	vec2 d = uv * 2.0 - 1.0;
	float pop = max(cj_back_out(progress / 0.6), 0.001);
	d /= pop;
	float r = length(d);
	float inside = cj_cov(r - 0.92);
	float fres = pow(clamp(r / 0.92, 0.0, 1.0), 5.0);
	vec2 sp = d / sqrt(max(1.0 - r * r, 0.08));
	float hex = cj_hexedge(sp * hex_scale * 0.25 + vec2(0.0, TIME * 0.08)) * hex_strength;
	float sweep = exp(-pow((d.x * 0.6 - d.y * 0.8) - (fract(TIME * sweep_speed) * 5.0 - 2.5), 2.0) * 10.0);
	float spec = exp(-(pow((d.x + 0.38) / 0.2, 2.0) + pow((d.y + 0.42) / 0.12, 2.0)));
	float flash = 1.0 - smoothstep(0.0, 0.5, progress);
	body = mix(color.rgb, color_rim.rgb, clamp(fres * 0.7 + sweep * 0.5 + spec + flash, 0.0, 1.0));
	alpha = inside * clamp(0.1 + fres * 0.8 + hex * (0.25 + fres) + sweep * 0.2 + spec * 0.7 + flash * 0.5, 0.0, 1.0);
	glow = color.rgb * glow_amount * (exp(-abs(r - 0.92) * 14.0) * 0.8 + hex * 0.3 * inside);
}

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	vec4 m = COLOR;
	COLOR = vec4((b * a + g) * m.rgb * m.a, clamp(a, 0.0, 1.0) * m.a);
}
