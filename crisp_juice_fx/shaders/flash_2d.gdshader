// Crisp Juice Particles - flash (2D). Radial flash / star burst / comic 'POW' burst. progress 0..1 drives the pop, the fade and the hollow ring.
// Driven by CrispFx2D: it sets `progress`. Tint it with the node's modulate (or the effect's `color`).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"

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

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	vec4 m = COLOR;
	COLOR = vec4((b * a + g) * m.rgb * m.a, clamp(a, 0.0, 1.0) * m.a);
}
