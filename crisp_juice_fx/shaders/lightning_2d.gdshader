// Crisp Juice Particles - lightning (2D). Jagged lightning bolt from the top of the quad to the bottom, with a branch. progress 0..1, or looping.
// Driven by CrispFx2D: it sets `progress`. Tint it with the node's modulate (or the effect's `color`).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform vec4 color_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.005, 0.2) = 0.035;
uniform float glow_width : hint_range(0.01, 0.5) = 0.09;
uniform float segments : hint_range(2.0, 30.0) = 9.0;
uniform float amplitude : hint_range(0.0, 1.0) = 0.42;
uniform float flicker_rate = 16.0;
uniform float seed = 0.0;
uniform bool looping = false;
float cj_bolt(vec2 uv, float sd, float amp) {
	float t = uv.y * segments;
	float i = floor(t);
	float f = fract(t);
	float off = mix(cj_hash(i + sd * 17.0), cj_hash(i + 1.0 + sd * 17.0), f) - 0.5;
	float t2 = uv.y * segments * 3.0;
	float j = floor(t2);
	float g = fract(t2);
	off += (mix(cj_hash(j + sd * 31.0 + 5.0), cj_hash(j + 1.0 + sd * 31.0 + 5.0), g) - 0.5) * 0.35;
	off *= amp * pow(sin(3.14159 * clamp(uv.y, 0.0, 1.0)), 0.6);
	return abs(uv.x - 0.5 - off);
}

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	float tt = looping ? TIME : progress * 1.4;
	float sd = floor(tt * flicker_rate) + seed;
	float env = looping ? 1.0 : (1.0 - smoothstep(0.55, 0.85, progress));
	float strike = looping ? 1.0 : step(uv.y, cj_ease_out(progress / 0.07));
	float flick = looping ? step(0.2, cj_hash(sd * 3.7)) : mix(1.0, step(0.3, cj_hash(sd * 3.7)), step(0.15, progress));
	float d = cj_bolt(uv, sd, amplitude);
	float core = 1.0 - smoothstep(width * 0.35, width, d);
	float g = exp(-d / glow_width);
	float bm = smoothstep(0.25, 0.4, uv.y) * smoothstep(0.85, 0.6, uv.y);
	vec2 buv = vec2(uv.x + (uv.y - 0.25) * 0.5 * (cj_hash(sd) - 0.5), uv.y);
	float d2 = cj_bolt(buv, sd + 7.0, amplitude * 1.3);
	float core2 = (1.0 - smoothstep(width * 0.25, width * 0.7, d2)) * bm;
	float edge = smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x);
	float k = env * strike * flick * edge;
	body = mix(color.rgb, color_core.rgb, clamp(core + core2, 0.0, 1.0));
	alpha = clamp(core + core2 * 0.8 + g * 0.35, 0.0, 1.0) * k;
	glow = color.rgb * (g * 0.9 + exp(-d2 / glow_width) * 0.4 * bm) * k;
}

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	vec4 m = COLOR;
	COLOR = vec4((b * a + g) * m.rgb * m.a, clamp(a, 0.0, 1.0) * m.a);
}
