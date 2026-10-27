extends Control

# Carga de texturas para los botones (ajusta las rutas a tus archivos .png)
const BTN_ON = preload("res://assets/images/ui/icon_check_on.webp")
const BTN_OFF = preload("res://assets/images/ui/icon_check_off.webp")

# Referencias a los TextureButton según tu árbol de escena
@onready var fondo: TextureRect = $Fondo
@onready var music_button: TextureButton = $Frente/Music/Button
@onready var sfx_button: TextureButton = $Frente/SoundEffects/Button
@onready var btn_es: TextureButton = $Frente/Idioma/Castellano/Button
@onready var btn_en: TextureButton = $Frente/Idioma/English/Button
@onready var btn_pt: TextureButton = $Frente/Idioma/Portugues/Button

func _ready() -> void:
	FondoDinamico.aplicar(fondo)
	# Conectamos las señales por código si no las conectaste en el editor
	if not music_button.is_connected("pressed", _on_music_button_pressed):
		music_button.connect("pressed", _on_music_button_pressed)
		
	if not sfx_button.is_connected("pressed", _on_sfx_button_pressed):
		sfx_button.connect("pressed", _on_sfx_button_pressed)

	btn_es.pressed.connect(func(): _seleccionar_idioma("es"))
	btn_en.pressed.connect(func(): _seleccionar_idioma("en"))
	btn_pt.pressed.connect(func(): _seleccionar_idioma("pt"))


	# Refrescamos la apariencia según los valores guardados en audio_manager
	_actualizar_boton_musica()
	_actualizar_boton_sfx()
	_actualizar_botones_idioma()

# --- MÚSICA ---
func _on_music_button_pressed() -> void:
	var nuevo_estado = !audio_manager.music_enabled
	audio_manager.set_music_enabled(nuevo_estado)
	_actualizar_boton_musica()
	audio_manager.play_ok1()

func _actualizar_boton_musica() -> void:
	if audio_manager.music_enabled:
		music_button.texture_normal = BTN_ON
		music_button.texture_pressed = BTN_ON
	else:
		music_button.texture_normal = BTN_OFF
		music_button.texture_pressed = BTN_OFF

# --- EFECTOS DE SONIDO (SFX) ---
func _on_sfx_button_pressed() -> void:
	var nuevo_estado = !audio_manager.sfx_enabled
	audio_manager.set_sfx_enabled(nuevo_estado)
	_actualizar_boton_sfx()
	audio_manager.play_ok1()

func _actualizar_boton_sfx() -> void:
	if audio_manager.sfx_enabled:
		sfx_button.texture_normal = BTN_ON
		sfx_button.texture_pressed = BTN_ON
	else:
		sfx_button.texture_normal = BTN_OFF
		sfx_button.texture_pressed = BTN_OFF

# ==========================================
# IDIOMA (MUTUA EXCLUSIÓN)
# ==========================================
func _seleccionar_idioma(nuevo_codigo: String) -> void:
	game_manager.cambiar_idioma(nuevo_codigo)
	_actualizar_botones_idioma()
	audio_manager.play_ok1()
	# Opcional: Si tienes textos traducibles en la misma pantalla de opciones, 
	# puedes llamar aquí a una función actualizar_textos_ui()

func _actualizar_botones_idioma() -> void:
	var idioma = game_manager.idioma_actual
	
	# Evaluamos cada botón individualmente según el idioma seleccionado
	_set_texture_check(btn_es, idioma == "es")
	_set_texture_check(btn_en, idioma == "en")
	_set_texture_check(btn_pt, idioma == "pt")

# Función auxiliar para aplicar la textura según el estado booleano
func _set_texture_check(button: TextureButton, activo: bool) -> void:
	var tex = BTN_ON if activo else BTN_OFF
	button.texture_normal = tex
	button.texture_pressed = tex

func _on_boton_options_pressed() -> void:
	audio_manager.play_ok1()
	get_tree().change_scene_to_file("res://scenes/title.tscn")
