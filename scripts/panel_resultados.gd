extends Control
class_name PanelResultados

signal reiniciar_solicitado
signal continuar_solicitado

@onready var fondo_desenfoque: Control = $FondoDesenfoque
@onready var fondo_panel: TextureRect = $FondoPanel
@onready var level_title: Label = $FondoPanel/LevelTitle
@onready var label_puntaje_final: Label = $FondoPanel/LabelPuntajeFinal
@onready var ribbon_amarilla: TextureRect = $FondoPanel/RibbonAmarilla
@onready var ribbon_roja: TextureRect = $FondoPanel/RibbonRoja
@onready var ribbon_azul: TextureRect = $FondoPanel/RibbonAzul
@onready var boton_ok: TextureButton = $FondoPanel/BotonOk
@onready var boton_reiniciar: TextureButton = $FondoPanel/BotonReiniciar

var escala_orig_amarilla: Vector2
var escala_orig_roja: Vector2
var escala_orig_azul: Vector2

func _ready() -> void:
	visible = false
	
	# Guardar escalas base de las ribbons
	if ribbon_amarilla:
		ribbon_amarilla.pivot_offset = ribbon_amarilla.size / 2
		escala_orig_amarilla = ribbon_amarilla.scale
	if ribbon_roja:
		ribbon_roja.pivot_offset = ribbon_roja.size / 2
		escala_orig_roja = ribbon_roja.scale
	if ribbon_azul:
		ribbon_azul.pivot_offset = ribbon_azul.size / 2
		escala_orig_azul = ribbon_azul.scale

	# Conectar botones
	if boton_ok:
		boton_ok.pressed.connect(_on_boton_ok_pressed)
	if boton_reiniciar:
		boton_reiniciar.pressed.connect(_on_boton_reiniciar_pressed)

func mostrar(nivel_id: int) -> void:
	if visible:
		return

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
