// Crisp Juice Particles - popup (2D). A sprite (or flip-book strip) that pops, rises, spins and fades - coin / gem / heart pickups. progress 0..1.
// Driven by CrispFx2D: it sets `progress`. Tint it with the node's modulate (or the effect's `color`).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://crisp_juice_fx/shaders/crisp_common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D sprite : source_color, filter_linear, repeat_disable;
uniform int frames : hint_range(1, 32) = 1;
uniform float rise : hint_range(0.0, 1.0) = 0.32;
uniform float spin_turns : hint_range(0.0, 8.0) = 2.0;
uniform vec4 sprite_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sprite_size : hint_range(0.05, 1.0) = 0.42;
uniform float start_y : hint_range(0.0, 1.0) = 0.66;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float glow_amount : hint_range(0.0, 2.0) = 0.45;

void cj_shade(vec2 uv, out vec3 body, out float alpha, out vec3 glow) {
	float p = progress;
	float pop = max(cj_back_out(p / 0.22), 0.001);
	vec2 c = vec2(0.5, start_y - rise * cj_ease_out(p / 0.6));
	vec2 l = (uv - c) / (sprite_size * pop) + 0.5;
	float inb = step(0.0, l.x) * step(l.x, 1.0) * step(0.0, l.y) * step(l.y, 1.0);
	float f = floor(fract(p * spin_turns) * float(frames));
	vec4 t = textureLod(sprite, vec2((clamp(l.x, 0.0, 1.0) + f) / float(frames), clamp(l.y, 0.0, 1.0)), 0.0);
	float fade = 1.0 - smoothstep(0.72, 1.0, p);
	float white = 1.0 - smoothstep(0.0, 0.16, p);
	body = mix(t.rgb * sprite_tint.rgb, vec3(1.0), white * 0.85);
	alpha = t.a * inb * fade;
	float gr = length((uv - c) / (sprite_size * pop));
	glow = glow_color.rgb * glow_amount * exp(-gr * gr * 3.0) * fade * smoothstep(1.0, 0.8, length(uv * 2.0 - 1.0));
}

void fragment() {
	vec3 b;
	float a;
	vec3 g;
	cj_shade(UV, b, a, g);
	vec4 m = COLOR;
	COLOR = vec4((b * a + g) * m.rgb * m.a, clamp(a, 0.0, 1.0) * m.a);
}
