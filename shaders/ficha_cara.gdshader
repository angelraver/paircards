shader_type spatial;
render_mode unshaded, cull_disabled;

// Cara superior de una ficha: proyecta una textura cuadrada sobre el disco
// de la tapa usando la posición local del vértice. Así no dependemos de las
// UV del GLB y la imagen queda orientada igual en todas las fichas.
uniform sampler2D albedo_textura : source_color, filter_linear, repeat_disable;
uniform float radio_cara : hint_range(0.001, 10.0) = 1.0;
uniform float brillo : hint_range(0.0, 1.0) = 1.0;
uniform vec3 color_base : source_color = vec3(0.72, 0.72, 0.75);

varying vec2 uv_cara;

void vertex() {
	// La cámara ve +Z como "arriba" y -X como "derecha" en pantalla.
	// Se invierte V para que la imagen no aparezca boca abajo.
	uv_cara = vec2(
		0.5 - VERTEX.x / (2.0 * radio_cara),
		0.5 - VERTEX.z / (2.0 * radio_cara)
	);
}

void fragment() {
	vec4 color = texture(albedo_textura, uv_cara);
	// Las cartas tienen un margen transparente; en la ficha ese margen se
	// rellena con el color del cuerpo para no perforar la cara superior.
	vec3 superficie = mix(color_base, color.rgb, step(0.5, color.a));
	ALBEDO = superficie * brillo;
}
