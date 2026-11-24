// Crisp Juice Particles - ribbon trail (3D), built by CrispTrail3D. Always faces the camera.
// The mesh stores the centre line: NORMAL = direction of travel, UV.x = age (0 head .. 1 tail), UV.y = side (0 / 1).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;

uniform vec4 color_head : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_tail : source_color = vec4(0.4, 0.8, 1.0, 0.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fx_fade : hint_range(0.0, 1.0) = 1.0;
uniform float width = 0.4;
uniform float brightness : hint_range(0.0, 4.0) = 1.0;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 tangent = normalize(NORMAL + vec3(1e-5, 0.0, 0.0));
	vec3 side = normalize(cross(tangent, normalize(cam - VERTEX)) + vec3(0.0, 1e-5, 0.0));
	float k = UV.x;
	float w = width * 0.5 * smoothstep(0.0, 0.18, k) * pow(1.0 - k, 1.2);
	VERTEX += side * (UV.y * 2.0 - 1.0) * w;
}

void fragment() {
	float k = UV.x;
	vec4 c = mix(color_head, color_tail, smoothstep(0.0, 1.0, k));
	float edge = 1.0 - pow(abs(UV.y * 2.0 - 1.0), 3.0);
	float core = 1.0 - pow(abs(UV.y * 2.0 - 1.0), 0.6);
	ALBEDO = mix(c.rgb, vec3(1.0), core * (1.0 - smoothstep(0.0, 0.5, k)) * 0.7) * tint.rgb * brightness;
	ALPHA = c.a * edge * (1.0 - k) * 0.85 * tint.a * fx_fade;
}
