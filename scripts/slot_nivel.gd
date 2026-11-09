extends Control

signal nivel_seleccionado(numero_nivel: int)

@onready var boton_nivel: TextureButton = $BotonNivel
@onready var label_numero: Label = $BotonNivel/LabelNumero

var nivel_id: int = 1


func _ready() -> void:
	if boton_nivel:
		boton_nivel.pressed.connect(func():
			if not boton_nivel.disabled:
				nivel_seleccionado.emit(nivel_id)
		)


func configurar(numero_nivel: int) -> void:
	nivel_id = numero_nivel
	
	# Consultamos el estado usando el ID del juego actualmente activo
	var id_juego: String = save_manager.juego_actual_seleccionado
	var desbloqueado = save_manager.es_nivel_desbloqueado(numero_nivel, id_juego)

	# El slot completo siempre debe estar visible si el nivel existe en el JSON
	visible = true

	if not desbloqueado:
		# --- NIVEL BLOQUEADO (MODO SOMBRA) ---
		# 1. Mostrar el botón pero desactivar interacción
		boton_nivel.visible = true
		boton_nivel.disabled = true
		boton_nivel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 2. Aplicar tinte oscuro y semi-transparente
		boton_nivel.modulate = Color(0.35, 0.35, 0.35, 0.9)

		# 3. Mostrar el número del nivel en tono sombra/atenuado
		label_numero.text = str(numero_nivel)
		label_numero.modulate = Color(0.7, 0.7, 0.7, 0.9)

		return

	# --- NIVEL DESBLOQUEADO ---
	# 1. Habilitar botón e interacciones
	boton_nivel.visible = true
	boton_nivel.disabled = false
	boton_nivel.mouse_filter = Control.MOUSE_FILTER_STOP

	# 2. Restablecer color brillante original (sin sombras)
	boton_nivel.modulate = Color.WHITE
	label_numero.modulate = Color.WHITE
	label_numero.text = str(numero_nivel)
