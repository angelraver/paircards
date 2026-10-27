shader_type canvas_item;

// Captura lo que hay renderizado en la pantalla detrás de este nodo
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Intensidad del desenfoque (a mayor número, más borroso)
uniform float nivel_desenfoque : hint_range(0.0, 5.0) = 2.5;

// Tinte para oscurecer un poco el fondo y darle más contraste a la UI
uniform vec4 oscurecer : source_color = vec4(0.0, 0.0, 0.0, 0.3);

void fragment() {
	// 1. Obtenemos la textura de la pantalla aplicando un nivel de detalle (LOD) para el borroso
	vec4 color_pantalla = textureLod(screen_texture, SCREEN_UV, nivel_desenfoque);
	
	// 2. Mezclamos el fondo borroso con el tinte oscuro
	COLOR = mix(color_pantalla, vec4(oscurecer.rgb, 1.0), oscurecer.a);
}