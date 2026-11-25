extends Control
class_name UIPuntaje

@export var texto_prefijo: String = "SCORE\n"
@export var digitos_minimos: int = 4

@onready var label: Label = $Label
@onready var label_max: Label = $Max
@onready var hi_score: Control = $HiScore
@onready var label_hi: Label = $HiScore/HiLabel
@onready var label_hi_num: Label = $HiScore/HiNumber

var puntaje_actual: int = 0
var puntaje_maximo: int = 0
var puntaje_hi: int = 0

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

## Fija el hi-score guardado para este nivel (score guardado previamente)
func establecer_hi_score(nuevo_hi: int) -> void:
	puntaje_hi = maxi(nuevo_hi, 0)
	actualizar_ui()

func actualizar_ui() -> void:
	if label:
		# Sin ceros a la izquierda, muestra el número tal cual
		label.text = str(puntaje_actual)
	if label_max:
		# Meta del nivel: "/ 1000" (oculto si el nivel aún no tiene máximo).
		label_max.visible = puntaje_maximo > 0
		if puntaje_maximo > 0:
			label_max.text = "/ %d" % puntaje_maximo
	if hi_score:
		# Muestra HI solo si hay un puntaje guardado previo, sin ceros a la izquierda
		hi_score.visible = puntaje_hi > 0
	if label_hi_num and puntaje_hi > 0:
		label_hi_num.text = str(puntaje_hi)
