shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float u_time : hint_range(0.0, 1000.0) = 0.0;
uniform float u_dissolve_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec2 u_direction = vec2(1.0, 0.0);
uniform vec4 u_color_1 : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform vec4 u_color_2 : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform vec4 u_color_3 : source_color = vec4(0.05, 0.15, 0.3, 1.0);

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    // 1. TAMAÑO DE LAS PARTÍCULAS
    // Cambiá 96.0 por 120.0 o más si las querés AÚN MÁS PEQUEÑAS
    vec2 grid_uv = floor(UV * vec2(75.0)); 
    float n = hash(grid_uv);

    // Progreso de la disolución (0.0 = intacto, 1.0 = desintegrado)
    float progress = 1.0 - u_dissolve_amount;

    // 2. VUELO HACIA LA DERECHA
    // Sumamos el desplazamiento (+ u_direction) para que se muevan a la derecha
    float speed = (0.15 + n * 0.35) * progress; 
    vec2 flying_uv = UV + normalize(u_direction) * speed;

    vec4 tex_flying = texture(TEXTURE, flying_uv);
    vec4 tex_original = texture(TEXTURE, UV);

    // Si el logo está 100% visible, dibujamos la textura intacta
    if (u_dissolve_amount >= 0.99) {
        if (tex_original.a < 0.1) discard;
        COLOR = tex_original;
    } else {
        float dir = dot(UV, normalize(u_direction));
        float border = u_dissolve_amount * 1.3 - 0.15;
        float is_dissolved = step(border, dir + (n - 0.5) * 0.25);

        // Si el píxel ya se disolvió en su posición original:
        if (is_dissolved > 0.5) {
            // Verificamos si hay una partícula en vuelo pasando por este UV
			float fly_dir = dot(flying_uv, normalize(u_direction));
			// Verifica si la textura muestreada en flying_uv aún NO ha sido disuelta
			float fly_dissolved = step(border, fly_dir - (n - 0.5) * 0.25);

            // Si la partícula en vuelo proviene de una zona visible de la textura
            if (tex_flying.a > 0.1 && fly_dissolved < 0.5) {
                float r = hash(grid_uv + floor(u_time * 8.0));
                vec4 col = mix(u_color_1, u_color_2, r);
                col = mix(col, u_color_3, step(0.7, r));
                COLOR = col; // Píxel volando pintado de energía
            } else {
                discard;
            }
        } else {
            // Parte del logo que sigue fija
            if (tex_original.a < 0.1) discard;
            
            // Borde brillante en la línea de corte
            float edge = step(border - 0.08, dir + (n - 0.5) * 0.25);
            if (edge > 0.5) {
                float r = hash(grid_uv + floor(u_time * 8.0));
                vec4 col = mix(u_color_1, u_color_2, r);
                col = mix(col, u_color_3, step(0.7, r));
                COLOR = col;
            } else {
                COLOR = tex_original;
            }
        }
    }
}