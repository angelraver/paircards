shader_type canvas_item;

uniform float u_time : hint_range(0.0, 1000.0) = 0.0;
uniform float glitch_intensity : hint_range(0.0, 0.1) = 0.015;
uniform float block_size : hint_range(1.0, 100.0) = 30.0; // Definición del bloque pixel

float random(float seed) {
	return fract(sin(seed * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	
	// Bloquea las alturas horizontales para crear los saltos tipicos del glitch
	float block = floor(uv.y * block_size);
	float noise = random(block + floor(u_time * 12.0));
	
	// Desplazamiento condicional (solo salta de a ratos)
	if (noise > 0.75) {
		uv.x += (random(block) - 0.5) * glitch_intensity;
	}
	
	// Muestra con aberracion cromatica en canal Alpha para fuentes
	float r = texture(TEXTURE, uv + vec2(glitch_intensity, 0.0)).a;
	float g = texture(TEXTURE, uv).a;
	float b = texture(TEXTURE, uv - vec2(glitch_intensity, 0.0)).a;
	
	vec4 text_color = vec4(r, g, b, texture(TEXTURE, uv).a);
	
	// Mantiene el azul base (#005095) o color aplicado al Label
	COLOR = text_color * COLOR;
}