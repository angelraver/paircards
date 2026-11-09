// Crisp Juice Particles - beam (2D). Column of light with scrolling streaks (level up, heal, teleport). progress 0..1, or looping.
// Driven by CrispFx2D: it sets `progress`. Tint it with the node's modulate (or the effect's `color`).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 color_core : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform float width : hint_range(0.05, 1.0) = 0.6;
uniform float streaks : hint_range(1.0, 30.0) = 7.0;
uniform float scroll_speed = 1.6;
uniform bool looping = false;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.5;

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	float env = looping ? 1.0 : cj_back_out(progress / 0.2);
	float fade = looping ? 1.0 : 1.0 - smoothstep(0.5, 1.0, progress);
	float narrow = looping ? 1.0 : mix(1.0, 0.25, smoothstep(0.45, 1.0, progress));
	float w = max(width * env * narrow * 0.5, 1e-3);
	float x = (uv.x - 0.5) / w;
	float prof = exp(-x * x * 2.2);
	float core = exp(-x * x * 14.0);
	float v = uv.y;
	float vert = smoothstep(0.0, 0.6, v) * smoothstep(1.0, 0.93, v);
	float n = cj_noise(vec2(x * 1.6 + 7.0, v * 2.0 * streaks / 7.0 + TIME * scroll_speed));
	float n2 = cj_noise(vec2(x * 3.1 - 3.0, v * 4.0 + TIME * scroll_speed * 1.7));
	float streak = smoothstep(0.5, 0.95, n * 0.6 + n2 * 0.5);
	float xm = smoothstep(0.5, 0.36, abs(uv.x - 0.5));
	body = mix(color.rgb, color_core.rgb, clamp(core + streak * 0.5, 0.0, 1.0));
	alpha = clamp(prof * (0.4 + 0.6 * streak) + core * 0.6, 0.0, 1.0) * vert * fade * xm;
	glow = color.rgb * glow_amount * prof * vert * fade * xm;
}

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	vec4 m = COLOR;
	COLOR = vec4((b * a + g) * m.rgb * m.a, clamp(a, 0.0, 1.0) * m.a);
}
