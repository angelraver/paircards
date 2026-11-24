// Crisp Juice Particles - ring (2D). Expanding ring (shockwave, ripple, ground ring). progress 0..1.
// Driven by CrispFx2D: it sets `progress`. Tint it with the node's modulate (or the effect's `color`).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_inner : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float radius_start : hint_range(0.0, 1.0) = 0.1;
uniform float radius_end : hint_range(0.0, 1.0) = 0.92;
uniform float thickness : hint_range(0.0, 1.0) = 0.2;
uniform float softness : hint_range(0.0, 1.0) = 0.4;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.4;
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	vec2 d = uv * 2.0 - 1.0;
	float r = length(d);
	float e = cj_ease_out(progress);
	float rad = mix(radius_start, radius_end, e);
	float th = thickness * (1.0 - e * 0.8) + 0.004;
	float dist = abs(r - rad);
	float band = 1.0 - smoothstep(th * 0.5 * (1.0 - softness), th * 0.5, dist);
	float fade = 1.0 - smoothstep(fade_start, 1.0, progress);
	float f = fill * smoothstep(rad, 0.0, r) * smoothstep(0.0, rad + 0.001, r + 0.25);
	body = mix(color_inner.rgb, color.rgb, smoothstep(rad - th * 0.5, rad + th * 0.5, r));
	alpha = max(band, f * 0.7) * fade * smoothstep(1.0, 0.96, r);
	glow = color.rgb * glow_amount * exp(-dist * 10.0) * fade * smoothstep(1.0, 0.85, r);
}

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	vec4 m = COLOR;
	COLOR = vec4((b * a + g) * m.rgb * m.a, clamp(a, 0.0, 1.0) * m.a);
}
