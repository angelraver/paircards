// Crisp Juice Particles - shield bubble on a sphere (3D).
// Driven by CrispFx3D: it sets `progress` (pop in), `tint` and `fade`.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fx_fade : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform int billboard_mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform vec4 color_rim : source_color = vec4(0.85, 1.0, 1.0, 1.0);
uniform float hex_scale : hint_range(1.0, 30.0) = 7.0;
uniform float hex_strength : hint_range(0.0, 1.0) = 0.4;
uniform float sweep_speed = 0.35;
varying vec3 v_local;

float cj_hexdist(vec2 p) { p = abs(p); return max(dot(p, normalize(vec2(1.0, 1.732))), p.x); }
float cj_hexedge(vec2 p) {
	vec2 rr = vec2(1.0, 1.732);
	vec2 h = rr * 0.5;
	vec2 a = mod(p, rr) - h;
	vec2 b = mod(p - h, rr) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	return smoothstep(0.4, 0.49, cj_hexdist(g));
}

void vertex() {
	v_local = VERTEX;
	VERTEX *= max(cj_back_out(progress / 0.6), 0.001);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.6);
	float hex = cj_hexedge(vec2(UV.x * 4.0, UV.y * 2.2) * hex_scale + vec2(0.0, TIME * 0.3)) * hex_strength;
	float sweep = exp(-pow(normalize(v_local).y * 2.5 - (fract(TIME * sweep_speed) * 6.0 - 3.0), 2.0) * 3.0);
	float flash = 1.0 - smoothstep(0.0, 0.5, progress);
	vec3 c = mix(color.rgb, color_rim.rgb, clamp(fres * 0.8 + sweep * 0.4 + flash, 0.0, 1.0));
	float a = clamp(0.06 + fres * 0.85 + hex * (0.2 + fres * 0.8) + sweep * 0.12 + flash * 0.5, 0.0, 1.0);
	ALBEDO = c * tint.rgb * brightness * (1.0 + fres * 0.6);
	ALPHA = a * tint.a * fx_fade;
}
