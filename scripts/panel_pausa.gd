extends Control
class_name PanelPausa

# Texturas on/off para los toggles (igual que en options)
const BTN_ON = preload("res://assets/images/ui/icon_check_on.webp")
const BTN_OFF = preload("res://assets/images/ui/icon_check_off.webp")

@onready var titulo: Label = $FondoPanel/Titulo
@onready var music_button: TextureButton = $FondoPanel/Music/Button
@onready var sfx_button: TextureButton = $FondoPanel/SoundEffects/Button
@onready var boton_home: TextureButton = $FondoPanel/BotonHome
@onready var boton_pausa: TextureButton = $FondoPanel/BotonPausa

func _ready() -> void:
	# El panel debe seguir funcionando con el árbol pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if not music_button.is_connected("pressed", _on_music_button_pressed):
		music_button.connect("pressed", _on_music_button_pressed)
	if not sfx_button.is_connected("pressed", _on_sfx_button_pressed):
		sfx_button.connect("pressed", _on_sfx_button_pressed)
	if not boton_home.is_connected("pressed", _on_boton_home_pressed):
		boton_home.connect("pressed", _on_boton_home_pressed)
	if not boton_pausa.is_connected("pressed", _on_boton_pausa_pressed):
		boton_pausa.connect("pressed", _on_boton_pausa_pressed)

	if game_manager.is_connected("idioma_cambiado", _on_idioma_cambiado) == false:
		game_manager.idioma_cambiado.connect(_on_idioma_cambiado)

	_actualizar_boton_musica()
	_actualizar_boton_sfx()
	_actualizar_titulo()

func mostrar() -> void:
	_actualizar_boton_musica()
	_actualizar_boton_sfx()
	_actualizar_titulo()
	visible = true
	get_tree().paused = true

func ocultar() -> void:
	visible = false
	get_tree().paused = false

func _on_idioma_cambiado(_nuevo_idioma: String) -> void:
	_actualizar_titulo()

func _actualizar_titulo() -> void:
	if titulo:
		titulo.text = game_manager.obtener_texto("pausa", "Pausa")

# --- MÚSICA (réplica de options) ---
func _on_music_button_pressed() -> void:
	var nuevo_estado = !audio_manager.music_enabled
	audio_manager.set_music_enabled(nuevo_estado)
	_actualizar_boton_musica()
	audio_manager.play_ok1()

func _actualizar_boton_musica() -> void:
	if music_button == null:
		return
	if audio_manager.music_enabled:
		music_button.texture_normal = BTN_ON
		music_button.texture_pressed = BTN_ON
	else:
		music_button.texture_normal = BTN_OFF
		music_button.texture_pressed = BTN_OFF

# --- EFECTOS DE SONIDO (réplica de options) ---
func _on_sfx_button_pressed() -> void:
	var nuevo_estado = !audio_manager.sfx_enabled
	audio_manager.set_sfx_enabled(nuevo_estado)
	_actualizar_boton_sfx()
	audio_manager.play_ok1()

func _actualizar_boton_sfx() -> void:
	if sfx_button == null:
		return
	if audio_manager.sfx_enabled:
		sfx_button.texture_normal = BTN_ON
		sfx_button.texture_pressed = BTN_ON
	else:
		sfx_button.texture_normal = BTN_OFF
		sfx_button.texture_pressed = BTN_OFF

# --- HOME: salir del nivel a la selección de niveles del juego actual ---
func _on_boton_home_pressed() -> void:
	audio_manager.play_ok1()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/seleccion_niveles.tscn")

# --- PAUSA: cerrar el panel y seguir jugando ---
func _on_boton_pausa_pressed() -> void:
	audio_manager.play_ok1()
	ocultar()
