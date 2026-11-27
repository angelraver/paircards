extends Control

## La intro se muestra solo la primera vez que se ve title en cada ejecución.
static var _intro_logo_realizada := false
static var _valor_desenfoque_objetivo := 2.5
static var _valor_desenfoque_capturado := false

const INTRO_ANIM := "Intro"
const INICIO_MOVIMIENTO_LOGO := 3.0

@export var duracion_desenfoque := 2.0
@export var parametro_desenfoque: StringName = &"nivel_desenfoque"

@onready var fondo: TextureRect = $Fondo
@onready var fondo_desenfoque: CanvasItem = $Fondo/FondoDesenfoque
@onready var start: TextureButton = $Start
@onready var boton_options: TextureButton = $Options
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _intro_animando := false
var _desenfoque_iniciado := false
var _material_desenfoque: ShaderMaterial
var _tween_desenfoque: Tween


func _ready() -> void:
	_conectar_botones()
	FondoDinamico.aplicar(fondo)
	audio_manager.ensure_title_bgm()
	_iniciar_intro()


func _conectar_botones() -> void:
	if not start.pressed.is_connected(_on_start_pressed):
		start.pressed.connect(_on_start_pressed)
	if not boton_options.pressed.is_connected(_on_boton_options_pressed):
		boton_options.pressed.connect(_on_boton_options_pressed)


func _iniciar_intro() -> void:
	_capturar_valor_desenfoque()
	if _intro_logo_realizada:
		_aplicar_valor_desenfoque(_valor_desenfoque_objetivo)
		return
	_intro_logo_realizada = true
	if animation_player == null:
		return
	_intro_animando = true
	_desenfoque_iniciado = false
	_aplicar_valor_desenfoque(0.0)
	start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not animation_player.animation_finished.is_connected(_on_intro_finished):
		animation_player.animation_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	animation_player.play(INTRO_ANIM)
	animation_player.seek(0.0, true)
	await get_tree().create_timer(INICIO_MOVIMIENTO_LOGO).timeout
	if _intro_animando:
		_iniciar_desenfoque()


func _on_intro_finished(_anim_name: StringName) -> void:
	_finalizar_intro()


func _finalizar_intro() -> void:
	if not _intro_animando:
		return
	_intro_animando = false
	if animation_player != null:
		var longitud := animation_player.current_animation_length
		animation_player.stop()
		animation_player.seek(longitud, true)
	start.mouse_filter = Control.MOUSE_FILTER_STOP
	boton_options.mouse_filter = Control.MOUSE_FILTER_STOP
	_iniciar_desenfoque()


func _capturar_valor_desenfoque() -> void:
	_material_desenfoque = fondo_desenfoque.material as ShaderMaterial
	if _material_desenfoque == null:
		push_warning("FondoDesenfoque no tiene ShaderMaterial; no se puede animar el desenfoque.")
		return
	if _valor_desenfoque_capturado:
		return
	var valor: Variant = _material_desenfoque.get_shader_parameter(parametro_desenfoque)
	if valor == null:
		push_warning("FondoDesenfoque no expone '%s'; no se puede animar el desenfoque." % String(parametro_desenfoque))
		return
	_valor_desenfoque_objetivo = float(valor)
	_valor_desenfoque_capturado = true


func _aplicar_valor_desenfoque(valor: float) -> void:
	if _material_desenfoque != null:
		_material_desenfoque.set_shader_parameter(parametro_desenfoque, valor)


func _iniciar_desenfoque() -> void:
	if _desenfoque_iniciado or _material_desenfoque == null:
		return
	_desenfoque_iniciado = true
	if _tween_desenfoque != null and _tween_desenfoque.is_valid():
		_tween_desenfoque.kill()
	_aplicar_valor_desenfoque(0.0)
	var ruta := "shader_parameter/" + String(parametro_desenfoque)
	_tween_desenfoque = create_tween()
	_tween_desenfoque.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_desenfoque.tween_property(_material_desenfoque, ruta, _valor_desenfoque_objetivo, duracion_desenfoque)


func _gui_input(event: InputEvent) -> void:
	_skip_intro_on_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_skip_intro_on_input(event)


func _skip_intro_on_input(event: InputEvent) -> void:
	if not _intro_animando:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_finalizar_intro()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_finalizar_intro()


func _on_start_pressed() -> void:
	_press_feedback(
		start,
		func():
			save_manager.juego_actual_seleccionado = "juego"
			get_tree().change_scene_to_file("res://scenes/seleccion_niveles.tscn")
	)


func _on_boton_options_pressed() -> void:
	_press_feedback(
		boton_options,
		func():
			audio_manager.play_ok1()
			get_tree().change_scene_to_file("res://scenes/options.tscn")
	)


func _press_feedback(button: Control, callback: Callable) -> void:
	Input.vibrate_handheld(25)

	var tween := create_tween()

	tween.tween_property(
		button,
		"scale",
		Vector2(button.scale.x - 0.05, button.scale.y - 0.05),
		0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_callback(callback)
