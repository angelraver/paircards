class_name SlotNivel
extends Control

signal nivel_seleccionado(numero_nivel: int)
signal level_selected(level_number: int)

@onready var boton_nivel: TextureButton = $BotonNivel
@onready var label_numero: Label = $BotonNivel/LabelNumero
@onready var contenedor_ribbons: Control = $ContenedorRibbons

var nivel_id: int = 1


func _ready() -> void:
	if boton_nivel != null and not boton_nivel.pressed.is_connected(_on_boton_nivel_pressed):
		boton_nivel.pressed.connect(_on_boton_nivel_pressed)


func configurar_nivel(numero_nivel: int, cantidad_ribbons: int = -1) -> void:
	configurar(numero_nivel)
	if cantidad_ribbons >= 0:
		establecer_ribbons(cantidad_ribbons)


func establecer_ribbons(cantidad: int) -> void:
	if contenedor_ribbons == null:
		return

	var total: int = contenedor_ribbons.get_child_count()
	var visibles: int = clampi(cantidad, 0, total)
	for i in range(total):
		var nodo: Node = contenedor_ribbons.get_child(i)
		if nodo is Control:
			(nodo as Control).visible = i < visibles


func configurar(numero_nivel: int) -> void:
	nivel_id = numero_nivel

	# Consultamos el estado usando el ID del juego actualmente activo
	var id_juego: String = save_manager.juego_actual_seleccionado
	var desbloqueado: bool = save_manager.es_nivel_desbloqueado(numero_nivel, id_juego)

	# El slot completo siempre debe estar visible si el nivel existe en el JSON
	visible = true

	if not desbloqueado:
		# --- NIVEL BLOQUEADO (MODO SOMBRA) ---
		boton_nivel.visible = true
		boton_nivel.disabled = true
		boton_nivel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton_nivel.modulate = Color(0.35, 0.35, 0.35, 0.9)
		label_numero.text = str(numero_nivel)
		label_numero.modulate = Color(0.7, 0.7, 0.7, 0.9)
		return

	# --- NIVEL DESBLOQUEADO ---
	boton_nivel.visible = true
	boton_nivel.disabled = false
	boton_nivel.mouse_filter = Control.MOUSE_FILTER_STOP
	boton_nivel.modulate = Color.WHITE
	label_numero.modulate = Color.WHITE
	label_numero.text = str(numero_nivel)


func _on_boton_nivel_pressed() -> void:
	if boton_nivel == null or boton_nivel.disabled:
		return
	nivel_seleccionado.emit(nivel_id)
	level_selected.emit(nivel_id)
