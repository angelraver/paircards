class_name SlotNivel
extends Control

signal nivel_seleccionado(numero_nivel: int)
signal level_selected(level_number: int)

@onready var boton_nivel: TextureButton = $BotonNivel
@onready var label_numero: Label = $BotonNivel/LabelNumero
@onready var contenedor_monedas: Control = $ContenedorMonedas

var nivel_id: int = 1


func _ready() -> void:
	establecer_monedas(0)
	if boton_nivel != null and not boton_nivel.pressed.is_connected(_on_boton_nivel_pressed):
		boton_nivel.pressed.connect(_on_boton_nivel_pressed)


func configurar_nivel(numero_nivel: int, cantidad_monedas: int = -1) -> void:
	configurar(numero_nivel)
	if cantidad_monedas >= 0:
		establecer_monedas(cantidad_monedas)


func establecer_monedas(cantidad: int) -> void:
	if contenedor_monedas == null:
		return

	var total: int = contenedor_monedas.get_child_count()
	var visibles: int = clampi(cantidad, 0, total)
	for i in range(total):
		var nodo: Node = contenedor_monedas.get_child(i)
		if nodo is Control:
			(nodo as Control).visible = i < visibles


func establecer_ribbons(cantidad: int) -> void:
	establecer_monedas(cantidad)


func configurar(numero_nivel: int) -> void:
	nivel_id = numero_nivel
	_actualizar_monedas(numero_nivel)

	var desbloqueado: bool = save_manager.es_nivel_desbloqueado(numero_nivel)

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


func _actualizar_monedas(numero_nivel: int) -> void:
	var score_objetivo: int = game_manager.obtener_score_nivel(numero_nivel)
	if score_objetivo <= 0:
		establecer_monedas(0)
		return

	var hi: int = maxi(save_manager.obtener_puntaje_nivel(numero_nivel), 0)
	var cantidad: int = 0
	if hi * 3 > score_objetivo:
		cantidad = 1
	if hi * 3 > score_objetivo * 2:
		cantidad = 2
	if hi >= score_objetivo:
		cantidad = 3
	establecer_monedas(cantidad)


func _on_boton_nivel_pressed() -> void:
	if boton_nivel == null or boton_nivel.disabled:
		return
	nivel_seleccionado.emit(nivel_id)
	level_selected.emit(nivel_id)
