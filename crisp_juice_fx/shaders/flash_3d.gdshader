// Crisp Juice Particles - flash (3D). Radial flash / star burst / comic 'POW' burst. progress 0..1 drives the pop, the fade and the hollow ring.
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
uniform vec4 color_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 0.5, 0.15, 1.0);
uniform int spikes : hint_range(0, 24) = 0;
uniform float spike_depth : hint_range(0.0, 1.0) = 0.5;
uniform float spike_sharpness : hint_range(0.3, 8.0) = 2.0;
uniform float rotation_degrees = 0.0;
uniform float hardness : hint_range(0.0, 1.0) = 0.0;
uniform float hollow : hint_range(0.0, 1.0) = 0.0;
uniform float stretch : hint_range(0.2, 6.0) = 1.0;
uniform float size_start : hint_range(0.0, 1.0) = 0.25;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.6;
uniform float spin : hint_range(-4.0, 4.0) = 0.0;

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	vec2 d = uv * 2.0 - 1.0;
	d.x /= stretch;
	d = cj_rot(d, radians(rotation_degrees) + spin * progress);
	float r = length(d);
	float a = atan(d.y, d.x);
	float grow = mix(size_start, 1.0, cj_back_out(progress / 0.3));
	float R = grow * 0.9;
	if (spikes > 0) {
		// triangle wave: 1 on a spike, 0 between spikes; the exponent makes the sides concave (thin rays) or straight (1)
		float tri = abs(fract(a * float(spikes) / 6.28318) * 2.0 - 1.0);
		R *= 1.0 - spike_depth * (1.0 - pow(tri, spike_sharpness));
	}
	float fade = 1.0 - smoothstep(0.45, 1.0, progress);
	float hard = cj_cov(r - R);
	float soft = pow(clamp(1.0 - r / max(R, 1e-3), 0.0, 1.0), 1.4);
	float shape = mix(soft, hard, hardness);
	float hole = R * hollow * cj_ease_out((progress - 0.12) / 0.88);
	shape *= mix(1.0, cj_cov(hole - r), step(0.001, hollow));
	float t = r / max(R, 1e-3);
	vec3 c = mix(color_core.rgb, color_edge.rgb, smoothstep(mix(0.1, 0.3, hardness), mix(0.8, 0.62, hardness), t));
	c = mix(c, outline_color.rgb, hardness * smoothstep(0.8, 0.88, t));
	body = c;
	alpha = shape * fade;
	glow = color_edge.rgb * glow_amount * exp(-r * 3.0 / max(grow, 0.05)) * fade * (1.0 - 0.6 * hardness);
	glow *= smoothstep(1.0, 0.55, length(uv * 2.0 - 1.0));
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
