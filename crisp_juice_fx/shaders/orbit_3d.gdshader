// Crisp Juice Particles - orbit (3D). Stars circling on an ellipse (dizzy / stunned). Runs on TIME; progress pops it in.
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
uniform sampler2D sprite : source_color, filter_linear, repeat_disable;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform int count : hint_range(1, 8) = 4;
uniform float speed = 0.7;
uniform float radius_x : hint_range(0.0, 0.5) = 0.36;
uniform float radius_y : hint_range(0.0, 0.5) = 0.13;
uniform float star_size : hint_range(0.02, 0.5) = 0.17;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.5;

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	float pop = max(cj_back_out(progress / 0.5), 0.001);
	body = vec3(0.0);
	alpha = 0.0;
	glow = vec3(0.0);
	float best = -9.0;
	for (int i = 0; i < 8; i++) {
		if (i >= count) { break; }
		float ang = TIME * speed * 6.28318 + float(i) / float(count) * 6.28318;
		float depth = sin(ang);
		vec2 pos = vec2(0.5 + cos(ang) * radius_x * pop, 0.5 + depth * radius_y * pop);
		float s = star_size * (0.78 + 0.28 * depth) * pop;
		vec2 l = cj_rot((uv - pos) / s, -ang * 1.5) + 0.5;
		float inb = step(0.0, l.x) * step(l.x, 1.0) * step(0.0, l.y) * step(l.y, 1.0);
		vec4 t = textureLod(sprite, clamp(l, 0.0, 1.0), 0.0) * inb;
		float shade = 0.72 + 0.28 * (depth * 0.5 + 0.5);
		if (t.a > 0.02 && depth > best) {
			body = mix(body, t.rgb * color.rgb * shade, t.a);
			alpha = max(alpha, t.a);
			best = depth - (1.0 - t.a) * 3.0;
		}
		glow += color.rgb * glow_amount * exp(-dot(uv - pos, uv - pos) / (s * s * 0.25)) * 0.35;
	}
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
