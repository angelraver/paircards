extends Node3D

@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego
@onready var boton_pausa: TextureButton = $UI/BotonPausa
@onready var panel_pausa: PanelPausa = $UI/PanelPausa as PanelPausa

var nivel_actual: int = 1
var ctrl_resultados: ControladorResultados

func _ready() -> void:
	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)

	if boton_pausa and not boton_pausa.is_connected("pressed", _on_boton_pausa_pressed):
		boton_pausa.pressed.connect(_on_boton_pausa_pressed)

func mostrar_panel_resultados() -> void:
	ctrl_resultados.mostrar(nivel_actual)

func _on_boton_pausa_pressed() -> void:
	if panel_resultados and panel_resultados.visible:
		return
	if panel_pausa == null:
		return
	if panel_pausa.visible:
		return
	audio_manager.play_ok1()
	panel_pausa.mostrar()
