// Crisp Juice Particles - slash (2D). Sword-swing arc that sweeps open and closes. progress 0..1.
// Driven by CrispFx2D: it sets `progress`. Tint it with the node's modulate (or the effect's `color`).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform float arc_degrees : hint_range(10.0, 350.0) = 160.0;
uniform float start_degrees = 200.0;
uniform float direction = 1.0;
uniform float radius : hint_range(0.1, 1.0) = 0.8;
uniform float width : hint_range(0.01, 0.8) = 0.28;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.5;

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	vec2 d = uv * 2.0 - 1.0;
	float r = length(d);
	float a = degrees(atan(d.y, d.x));
	float s = mod((a - start_degrees) * direction + 720.0, 360.0) / arc_degrees;
	float head = cj_ease_out(progress / 0.28) * 1.06;
	float tail = pow(clamp((progress - 0.18) / 0.82, 0.0, 1.0), 1.5) * 1.06;
	float fade = 1.0 - smoothstep(0.7, 1.0, progress);
	float k = clamp((s - tail) / max(head - tail, 1e-3), 0.0, 1.0);
	float inside = step(tail, s) * step(s, head) * step(s, 1.0);
	float thick = width * pow(sin(3.14159 * k), 0.6) * (0.25 + 0.75 * k);
	float outer = radius;
	float inner = radius - thick;
	float band = cj_cov(r - outer) * smoothstep(inner, inner + thick * 0.7 + 0.001, r) * inside;
	float edge = smoothstep(inner + thick * 0.45, outer, r);
	body = mix(color.rgb, color_core.rgb, edge * (0.45 + 0.55 * k));
	alpha = band * (0.5 + 0.5 * k) * fade;
	float halo = exp(-abs(r - (outer - thick * 0.4)) / 0.06) * inside * k;
	glow = color.rgb * glow_amount * halo * fade * smoothstep(1.0, 0.9, r);
}

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	vec4 m = COLOR;
	COLOR = vec4((b * a + g) * m.rgb * m.a, clamp(a, 0.0, 1.0) * m.a);
}
