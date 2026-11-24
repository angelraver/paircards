// Crisp Juice Particles - crack (3D). Ground cracks that snap open from the centre with a hot glow, then fade. progress 0..1.
// Driven by CrispFx3D: it sets `progress`, `tint` and `fx_fade`. billboard_mode: 0 = mesh as placed, 1 = face the camera,
// 2 = face the camera but stay upright (beams, bolts).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fx_fade : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform int billboard_mode : hint_range(0, 2) = 1;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.13, 0.08, 0.1, 1.0);
uniform vec4 scorch_color : source_color = vec4(0.25, 0.17, 0.15, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float glow_amount : hint_range(0.0, 2.0) = 1.0;
uniform int rays : hint_range(3, 12) = 8;
uniform float seed = 0.0;
float cj_zig(float x, float s) {
	return mix(cj_hash(floor(x) + s), cj_hash(floor(x) + 1.0 + s), fract(x)) - 0.5;
}
float cj_crack(float a, float r, float ang, float len, float w0, float s) {
	float da = mod(a - ang + 3.14159, 6.28318) - 3.14159;
	float off = cj_zig(r * 9.0, s) * 0.07 + cj_zig(r * 23.0, s + 5.0) * 0.025;
	float dp = abs(da * r - off * smoothstep(0.0, 0.15, r));
	float w = w0 * (1.0 - r / max(len, 1e-3)) + 0.005;
	return (1.0 - smoothstep(w * 0.5, w, dp)) * step(r, len) * step(abs(da), 1.4);
}

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	vec2 d = uv * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x);
	float reveal = cj_ease_out(progress / 0.12);
	float fade = 1.0 - smoothstep(0.65, 1.0, progress);
	float m = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= rays) { break; }
		float fi = float(i);
		float ang = fi / float(rays) * 6.28318 + (cj_hash(fi + seed) - 0.5) * 0.6;
		float len = (0.62 + cj_hash(fi * 3.1 + seed) * 0.33) * reveal;
		m = max(m, cj_crack(a, r, ang, len, 0.034, fi * 7.0 + seed));
		float bang = ang + (cj_hash(fi * 5.7 + seed) - 0.5) * 0.9;
		float bl = len * (0.55 + 0.3 * cj_hash(fi * 2.3 + seed));
		m = max(m, cj_crack(a, r, bang, bl, 0.02, fi * 13.0 + seed + 40.0) * step(len * 0.3, r));
	}
	float edge = 0.13 + (cj_noise(vec2(a * 2.5 + seed, 1.0)) - 0.5) * 0.05;
	float crater = cj_cov(r - edge * reveal);
	float rimc = exp(-abs(r - edge * reveal) / 0.025) * reveal;
	float scorch = exp(-r * r * 5.0) * 0.4 * reveal;
	float hot = 1.0 - smoothstep(0.03, 0.45, progress);
	vec3 c = mix(scorch_color.rgb, color.rgb, max(m, crater));
	c = mix(c, glow_color.rgb, clamp(m * hot * 0.7 + rimc * 0.5 * hot, 0.0, 1.0));
	body = c;
	alpha = clamp(max(max(m, crater * 0.95), scorch), 0.0, 1.0) * fade * smoothstep(1.0, 0.9, r);
	glow = glow_color.rgb * glow_amount * (m * 0.4 + rimc * 0.4 + crater * 0.2) * (0.15 + 0.85 * hot) * fade;
}

void vertex() {
	if (billboard_mode == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (billboard_mode == 2) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	float ga = clamp(max(max(g.r, g.g), g.b), 0.0, 1.0);
	float aa = clamp(a + ga * (1.0 - a), 0.0, 1.0);
	vec3 c = (b * a + g) / max(aa, 1e-3);
	ALBEDO = c * tint.rgb * brightness;
	ALPHA = aa * tint.a * fx_fade;
}
