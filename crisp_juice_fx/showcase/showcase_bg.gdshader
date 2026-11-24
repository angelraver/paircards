// Crisp Juice Particles - showcase background (vertical gradient + soft vignette + faint dots).
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.09, 0.08, 0.17, 1.0);
uniform vec4 bottom : source_color = vec4(0.16, 0.13, 0.28, 1.0);
uniform float dots = 0.025;
void fragment() {
	vec3 c = mix(top.rgb, bottom.rgb, UV.y);
	vec2 d = UV - 0.5;
	c *= 1.0 - dot(d, d) * 0.5;
	vec2 g = fract(UV * vec2(96.0, 54.0)) - 0.5;
	c += dots * (1.0 - smoothstep(0.05, 0.1, length(g)));
	COLOR = vec4(c, 1.0);
}
