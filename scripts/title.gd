extends Control

## Duración de la subida del logo en la intro.
const DURACION_INTRO_LOGO := 5.0
## La intro se muestra solo la primera vez que se ve title en cada ejecución.
static var _intro_logo_realizada := false

@onready var logo: TextureRect = $Logo
@onready var fondo: TextureRect = $Fondo
@onready var imagen_juegos: TextureButton = $ImagenJuegos
@onready var boton_prizes: TextureButton = $Prizes
@onready var boton_options: TextureButton = $Options


func _ready() -> void:
	FondoDinamico.aplicar(fondo)
	# Música de fondo de title/options: vive en el autoload audio_manager
	# para que continúe sin cortes al ir y volver de options.
	audio_manager.ensure_title_bgm()
	var era_primera_vez := not _intro_logo_realizada
	_animar_intro_logo()
	if era_primera_vez:
		_animar_intro_botones()


## El logo aparece en la mitad vertical y sube hasta su posición.
## Solo la primera vez; al volver a title ya está en su sitio.
func _animar_intro_logo() -> void:
	if _intro_logo_realizada:
		return
	_intro_logo_realizada = true
	if logo == null:
		return
	var destino_y := logo.position.y
	await get_tree().process_frame
	if not is_instance_valid(logo) or not logo.is_inside_tree():
		return
	var contenedor := logo.get_parent() as Control
	if contenedor == null or contenedor.size.y <= 0.0:
		return
	var inicio_y := (contenedor.size.y - logo.size.y) / 2.0
	if inicio_y <= destino_y:
		return
	logo.position.y = inicio_y
	var tween := logo.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(logo, "position:y", destino_y, DURACION_INTRO_LOGO)


## En la primera vez: Options entra desde la izquierda y Prizes desde la
## derecha, ambos hasta su posición de la escena. Solo `position:x`.
func _animar_intro_botones() -> void:
	var ancho_pantalla := get_viewport_rect().size.x
	var entradas: Array = [[boton_options, -1.0], [boton_prizes, 1.0]]
	for item in entradas:
		var boton: Control = item[0]
		if boton == null:
			continue
		var lado: float = item[1]
		var destino_x: float = boton.position.x
		var ancho: float = boton.offset_right - boton.offset_left
		if lado < 0.0:
			boton.position.x = -ancho
		else:
			boton.position.x = ancho_pantalla
		var tween: Tween = boton.create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(boton, "position:x", destino_x, DURACION_INTRO_LOGO)


func _on_imagen_juegos_pressed() -> void:
	_press_feedback(
		$ImagenJuegos,
		func():
			save_manager.juego_actual_seleccionado = "plinko"
			get_tree().change_scene_to_file("res://scenes/seleccion_niveles.tscn")
	)


func _on_boton_prizes_pressed() -> void:
	_press_feedback(
		$Prizes,
		func():
			audio_manager.play_ok1()
			get_tree().change_scene_to_file("res://scenes/premios.tscn")
	)


func _on_boton_options_pressed() -> void:
	_press_feedback(
		$Options,
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
