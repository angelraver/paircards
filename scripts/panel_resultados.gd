extends Control
class_name PanelResultados

signal reiniciar_solicitado

@onready var fondo_desenfoque: Control = $FondoDesenfoque
@onready var fondo_panel: TextureRect = $FondoPanel
@onready var level_title: Label = $FondoPanel/LevelTitle
@onready var boton_ok: TextureButton = $FondoPanel/BotonOk
@onready var boton_reiniciar: TextureButton = $FondoPanel/BotonReiniciar
@onready var moneda1: TextureRect = $FondoPanel/moneda1
@onready var moneda2: TextureRect = $FondoPanel/moneda2
@onready var moneda3: TextureRect = $FondoPanel/moneda3
@onready var label_puntaje_final: Label = $FondoPanel/LabelPuntajeFinal

var _nivel_id_actual: int = 0

func _ready() -> void:
	visible = false
	_ocultar_monedas()

	# Conectar botones
	if boton_ok:
		boton_ok.pressed.connect(_on_boton_ok_pressed)
	if boton_reiniciar:
		boton_reiniciar.pressed.connect(_on_boton_reiniciar_pressed)

	if not game_manager.is_connected("idioma_cambiado", _on_idioma_cambiado):
		game_manager.idioma_cambiado.connect(_on_idioma_cambiado)

func mostrar(nivel_id: int, puntaje: int = 0, nivel_superado: bool = false, score_objetivo: int = 0) -> void:
	if visible:
		return
	visible = true
	_ocultar_monedas()

	_nivel_id_actual = nivel_id
	_actualizar_titulo_nivel()
	if label_puntaje_final:
		label_puntaje_final.text = "%d / %d" % [maxi(puntaje, 0), maxi(score_objetivo, 0)]

	if nivel_superado:
		save_manager.registrar_puntaje_nivel(nivel_id, puntaje)
		_actualizar_monedas(puntaje, score_objetivo)

func _actualizar_titulo_nivel() -> void:
	if level_title == null or _nivel_id_actual <= 0:
		return
	var id_juego: String = save_manager.juego_actual_seleccionado
	var titulo_str: String = game_manager.obtener_titulo_nivel(str(_nivel_id_actual), id_juego)
	level_title.text = "%d\n%s" % [_nivel_id_actual, titulo_str]

func _on_idioma_cambiado(_nuevo_idioma: String) -> void:
	if visible:
		_actualizar_titulo_nivel()

func _ocultar_monedas() -> void:
	if moneda1:
		moneda1.visible = false
	if moneda2:
		moneda2.visible = false
	if moneda3:
		moneda3.visible = false

func _actualizar_monedas(puntaje: int, score_objetivo: int) -> void:
	if score_objetivo <= 0:
		return
	var puntos: int = maxi(puntaje, 0)
	if moneda1:
		moneda1.visible = puntos * 3 > score_objetivo
	if moneda2:
		moneda2.visible = puntos * 3 > score_objetivo * 2
	if moneda3:
		moneda3.visible = puntos >= score_objetivo

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
