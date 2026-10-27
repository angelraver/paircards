extends Control
class_name UIPuntaje

@export var texto_prefijo: String = "SCORE\n"
@export var digitos_minimos: int = 4

@onready var label: Label = $Label
@onready var label_max: Label = $Max

var puntaje_actual: int = 0
var puntaje_maximo: int = 0

func _ready() -> void:
	actualizar_ui()

func establecer_puntaje(nuevo_puntaje: int) -> void:
	puntaje_actual = nuevo_puntaje
	actualizar_ui()

## Fija el puntaje máximo del nivel (meta de la cinta azul) que se muestra
## debajo del número como "/ max".
func establecer_maximo(nuevo_maximo: int) -> void:
	puntaje_maximo = maxi(nuevo_maximo, 0)
	actualizar_ui()

func actualizar_ui() -> void:
	if label:
		# Mantiene el formato con ceros a la izquierda (ej. 0005)
		label.text = str(puntaje_actual).pad_zeros(digitos_minimos)
	if label_max:
		# Meta del nivel: "/ 1000" (oculto si el nivel aún no tiene máximo).
		label_max.visible = puntaje_maximo > 0
		if puntaje_maximo > 0:
			label_max.text = "/ %d" % puntaje_maximo
