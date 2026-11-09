// Crisp Juice Particles - portal (3D). Swirling portal. progress is the opening (0 = closed, 1 = open); the swirl runs on TIME.
// Driven by CrispFx3D: it sets `progress`, `tint` and `fx_fade`. billboard_mode: 0 = mesh as placed, 1 = face the camera,
// 2 = face the camera but stay upright (beams, bolts).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fx_fade : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform int billboard_mode : hint_range(0, 2) = 1;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color_a : source_color = vec4(0.42, 0.24, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.5, 0.9, 1.0);
uniform vec4 color_core : source_color = vec4(0.09, 0.03, 0.2, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 1.0, 1.0);
uniform float arms : hint_range(1.0, 8.0) = 3.0;
uniform float twist : hint_range(0.0, 10.0) = 3.0;
uniform float spin_speed = 1.2;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.45;

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	vec2 d = uv * 2.0 - 1.0;
	float open = max(cj_back_out(progress), 0.001);
	d /= open;
	float r = length(d);
	float a = atan(d.y, d.x);
	float wob = cj_fbm(d * 2.2 + vec2(TIME * 0.35, -TIME * 0.25));
	float sw = a * arms + log(max(r, 0.03)) * twist * 1.6 + TIME * spin_speed * 3.0 + wob * 2.2;
	float s = smoothstep(0.3, 0.8, 0.5 + 0.5 * sin(sw));
	float s2 = smoothstep(0.75, 0.95, 0.5 + 0.5 * sin(sw * 2.0 + 1.3));
	float edge_r = 0.9 + (wob - 0.5) * 0.06;
	float bodym = cj_cov(r - edge_r);
	float rim = exp(-abs(r - edge_r + 0.04) / 0.035);
	float core = smoothstep(0.6, 0.0, r);
	vec3 c = mix(color_a.rgb * 0.6, color_b.rgb, s * smoothstep(0.08, 0.7, r));
	c = mix(c, vec3(1.0), s2 * 0.35 * smoothstep(0.2, 0.8, r));
	c = mix(c, color_core.rgb, core * 0.92);
	c = mix(c, rim_color.rgb, rim * 0.8);
	body = c;
	alpha = bodym;
	glow = color_b.rgb * glow_amount * (exp(-max(r - edge_r, 0.0) * 12.0) * (1.0 - bodym) + rim * 0.35);
	glow *= smoothstep(1.0, 0.85, length(uv * 2.0 - 1.0)) * step(0.001, progress);
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
