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

func mostrar(nivel_id: int, puntaje: int, puntaje_maximo: int, id_juego: String = "") -> void:
	if visible:
		return

	if id_juego == "":
		id_juego = save_manager.juego_actual_seleccionado

	# Título e información
	if level_title:
		var titulo_str = game_manager.obtener_titulo_nivel(str(nivel_id), id_juego)
		level_title.text = "Nivel %d\n%s" % [nivel_id, titulo_str]

	if label_puntaje_final:
		label_puntaje_final.text = "%d / %d" % [puntaje, puntaje_maximo]

	# Cálculo de cintas/ribbons
	var umbral_1: float = puntaje_maximo * (1.0 / 3.0)
	var umbral_2: float = puntaje_maximo * (2.0 / 3.0)
	var umbral_3: float = float(puntaje_maximo)

	var gano_amarilla = (puntaje >= umbral_1)
	var gano_roja = (puntaje >= umbral_2)
	var gano_azul = (puntaje >= umbral_3)

	ribbon_amarilla.visible = false
	ribbon_roja.visible = false
	ribbon_azul.visible = false

	# Guardado de progreso centralizado
	save_manager.registrar_puntaje_nivel(nivel_id, puntaje, puntaje_maximo, id_juego)

	# Sin ribbons ganadas suena fail; con al menos una, welldone + pop por ribbon.
	if gano_amarilla or gano_roja or gano_azul:
		audio_manager.play_welldone()
	else:
		audio_manager.play_fail()
	visible = true
	animar_aparicion(gano_amarilla, gano_roja, gano_azul)

func animar_aparicion(gano_amarilla: bool, gano_roja: bool, gano_azul: bool) -> void:
	fondo_desenfoque.modulate.a = 0.0
	var tween_desenfoque = create_tween()
	tween_desenfoque.tween_property(fondo_desenfoque, "modulate:a", 1.0, 0.2)

	await get_tree().process_frame

	var escala_original = fondo_panel.scale
	fondo_panel.pivot_offset = fondo_panel.size / 2
	fondo_panel.scale = escala_original * 0.8
	fondo_panel.modulate.a = 0.0

	var tween_panel = create_tween().set_parallel(true)
	tween_panel.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_panel.tween_property(fondo_panel, "scale", escala_original, 1.0)
	tween_panel.tween_property(fondo_panel, "modulate:a", 1.0, 1.0)

	await tween_panel.finished

	if gano_amarilla:
		animar_pop_ribbon(ribbon_amarilla, escala_orig_amarilla)
		await get_tree().create_timer(0.12).timeout

	if gano_roja:
		animar_pop_ribbon(ribbon_roja, escala_orig_roja)
		await get_tree().create_timer(0.12).timeout

	if gano_azul:
		animar_pop_ribbon(ribbon_azul, escala_orig_azul)

func animar_pop_ribbon(ribbon: Control, escala_objetivo: Vector2) -> void:
	ribbon.scale = Vector2.ZERO
	ribbon.visible = true
	audio_manager.play_pop()
	var tween = create_tween()
	tween.tween_property(ribbon, "scale", escala_objetivo * 1.1, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ribbon, "scale", escala_objetivo, 0.10)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

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
