shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float u_time : hint_range(0.0, 1000.0) = 0.0;
uniform float scanline_count : hint_range(0.0, 1800.0) = 400.0;
uniform float scanline_intensity : hint_range(0.0, 0.3) = 0.08;
uniform float perlin_intensity : hint_range(0.0, 0.05) = 0.005; // Fuerza del ruido Perlin
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.003;

// --- Generador de Ruido Perlin 2D Procedural ---
vec2 hash_2d(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float perlin_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(dot(hash_2d(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
		    dot(hash_2d(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash_2d(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
		    dot(hash_2d(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	// Sin la función curve(SCREEN_UV), las esquinas se mantienen totalmente rectas
	vec2 uv = SCREEN_UV;
	
	// Calculamos la interferencia de ruido Perlin animado sobre las coordenadas UV
	vec2 perlin_uv = uv * 10.0 + vec2(0.0, u_time * 2.0);
	float n = perlin_noise(perlin_uv);
	
	// Aplicamos el desplazamiento del ruido Perlin a las UV
	vec2 distorted_uv = uv + vec2(n) * perlin_intensity;

	// Lectura de los canales de color con aberración cromática sobre las UV distorsionadas
	float r = texture(SCREEN_TEXTURE, distorted_uv + vec2(chromatic_aberration, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, distorted_uv).g;
	float b = texture(SCREEN_TEXTURE, distorted_uv - vec2(chromatic_aberration, 0.0)).b;
	
	// Scanlines horizontales planas
	float scanline = sin(uv.y * scanline_count * 3.14159) * scanline_intensity;
	vec3 final_color = vec3(r, g, b) - scanline;
	
	COLOR = vec4(final_color, 1.0);
}