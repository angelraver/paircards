extends Control
class_name UILevelNumber

@export var texto_prefijo: String = ""

@onready var label: Label = $Label

var nivel_actual: int = 1

func _ready() -> void:
	actualizar_ui()

func establecer_nivel(nuevo_nivel: int) -> void:
	print("llamado")
	nivel_actual = nuevo_nivel
	actualizar_ui()

func actualizar_ui() -> void:
	if label:
		label.text = texto_prefijo + str(nivel_actual)
