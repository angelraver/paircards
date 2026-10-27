extends Control
class_name UITimer

signal tiempo_agotado

@onready var label: Label = $Label

var tiempo_restante: float = 0.0
var corriendo: bool = false
var en_titileo: bool = false

# Colores configurables
const COLOR_BLANCO = Color.WHITE
const COLOR_AMARILLO = Color(1.0, 0.85, 0.0) # Amarillo brillante
const COLOR_ROJO = Color(0.9, 0.15, 0.15)     # Rojo alerta

func _process(delta: float) -> void:
	if not corriendo:
		return

	tiempo_restante -= delta

	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		corriendo = false
		actualizar_ui()
		_iniciar_animacion_fin()
		return

	actualizar_ui()

func iniciar(segundos: float) -> void:
	tiempo_restante = segundos
	corriendo = true
	en_titileo = false
	visible = true
	if label:
		label.modulate.a = 1.0
	actualizar_ui()

func detener() -> void:
	corriendo = false

func actualizar_ui() -> void:
	if not label:
		return

	# Formato con un decimal (x.x)
	label.text = "%.1f" % tiempo_restante

	# Cambio de color según umbrales de tiempo
	if not en_titileo:
		if tiempo_restante < 5.0:
			label.modulate = COLOR_ROJO
		elif tiempo_restante < 10.0:
			label.modulate = COLOR_AMARILLO
		else:
			label.modulate = COLOR_BLANCO

func _iniciar_animacion_fin() -> void:
	en_titileo = true
	if label:
		label.modulate = COLOR_ROJO

	# Animación de titileo (opacidad) durante 2 segundos
	var tween = create_tween()
	
	# Parpadea 4 veces (0.25s visible, 0.25s invisible)
	for i in range(4):
		tween.tween_property(label, "modulate:a", 0.0, 0.25)
		tween.tween_property(label, "modulate:a", 1.0, 0.25)

	tween.finished.connect(func():
		tiempo_agotado.emit()
	)
