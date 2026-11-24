extends Control
class_name PanelResultados

signal reiniciar_solicitado

@onready var fondo_desenfoque: Control = $FondoDesenfoque
@onready var fondo_panel: TextureRect = $FondoPanel
@onready var level_title: Label = $FondoPanel/LevelTitle
@onready var boton_ok: TextureButton = $FondoPanel/BotonOk
@onready var boton_reiniciar: TextureButton = $FondoPanel/BotonReiniciar

func _ready() -> void:
	visible = false

	# Conectar botones
	if boton_ok:
		boton_ok.pressed.connect(_on_boton_ok_pressed)
	if boton_reiniciar:
		boton_reiniciar.pressed.connect(_on_boton_reiniciar_pressed)

func mostrar(nivel_id: int) -> void:
	if visible:
		return
	visible = true

	if level_title:
		level_title.text = "Nivel %d" % [nivel_id]

	# Guardado de progreso centralizado
	#save_manager.registrar_puntaje_nivel(nivel_id, puntaje, puntaje_maximo, id_juego)

func _on_boton_reiniciar_pressed() -> void:
	audio_manager.play_ok1()
	visible = false
	reiniciar_solicitado.emit()

func _on_boton_ok_pressed() -> void:
	audio_manager.play_ok1()
	if save_manager.premio_recien_desbloqueado != "":
		get_tree().change_scene_to_file("res://scenes/premio_desbloqueado.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/seleccion_niveles.tscn")
