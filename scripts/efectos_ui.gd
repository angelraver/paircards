# res://scripts/efectos_ui.gd
extends Node

const ESCENA_PUNTOS_FLOTANTES: PackedScene = preload("res://scenes/puntos_flotantes.tscn")

func crear_efecto_puntos(posicion_3d: Vector3, valor_puntos: int) -> void:
	# 1. Obtener la cámara 3D activa en el viewport actual
	var camara: Camera3D = get_viewport().get_camera_3d()
	if not camara:
		return

	# 2. Instanciar el efecto
	var efecto = ESCENA_PUNTOS_FLOTANTES.instantiate()

	# 3. Buscar el CanvasLayer activo en la escena para renderizar en UI 2D
	# (Si no encuentra un CanvasLayer, lo agrega al nodo raíz de la escena activa)
	var contenedor_ui: Node = _obtener_contenedor_ui()
	contenedor_ui.add_child(efecto)

	# 4. Configurar el texto y color
	var label = efecto.get_node("Label") as Label
	label.text = "+%d" % valor_puntos
	
	if valor_puntos > 100:
		label.modulate = Color(1.0, 0.9, 0.0) # Amarillo/Dorado
	else:
		label.modulate = Color(1.0, 1.0, 1.0) # Blanco estándar

	# 5. Calcular la posición inicial en pantalla (desplazado un poco hacia arriba en 3D)
	var posicion_3d_objetivo = posicion_3d + Vector3(0.0, 0.3, 0.0)
	var posicion_pantalla = camara.unproject_position(posicion_3d_objetivo)
	efecto.position = posicion_pantalla

	# 6. Animación con Tween
	var tween = create_tween()
	var posicion_final_y = posicion_pantalla.y - 60.0
	
	tween.tween_property(efecto, "position:y", posicion_final_y, 1.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.set_parallel(true)
	tween.tween_property(efecto, "modulate:a", 0.0, 1.5)\
		.set_trans(Tween.TRANS_LINEAR)

	tween.chain().tween_callback(efecto.queue_free)

func _obtener_contenedor_ui() -> Node:
	# Busca automáticamente un CanvasLayer dentro de la escena que se está ejecutando
	var escena_actual = get_tree().current_scene
	for child in escena_actual.get_children():
		if child is CanvasLayer:
			return child
	return escena_actual
