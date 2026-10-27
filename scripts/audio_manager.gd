extends Node

# --- NODOS EXISTENTES DE EFECTOS ---
@onready var start: AudioStreamPlayer = $Start
@onready var welldone: AudioStreamPlayer = $Welldone
@onready var prize: AudioStreamPlayer = $Prize
@onready var ok1: AudioStreamPlayer = $Ok1
@onready var pop: AudioStreamPlayer = $Pop
@onready var fail1: AudioStreamPlayer = $Fail1

# --- CONTROL DE ESTADO GLOBAL ---
var music_enabled: bool = true
var sfx_enabled: bool = true

# Música de fondo de las escenas title/options.
const TITLE_BGM: AudioStream = preload("res://assets/sounds/themes/main_theme.ogg")

# Un theme por minijuego. Se cargan bajo demanda y se cachean.
const THEME_PATHS := {
	"tincanalley": "res://assets/sounds/themes/tincanalley.ogg",
	"whackamole": "res://assets/sounds/themes/whackamole.ogg",
	"plinko": "res://assets/sounds/themes/plinko.ogg",
	"ringtoss": "res://assets/sounds/themes/ringtoss.ogg",
	"duckshoot": "res://assets/sounds/themes/duckshoot.ogg",
}

var _theme_cache := {}

# Player para la música de fondo (vive en este autoload, por eso
# la música continúa sin cortes entre title <-> options).
var bgm_player: AudioStreamPlayer

func _ready() -> void:
	# 1. Inicializamos el reproductor de música de fondo
	bgm_player = AudioStreamPlayer.new()
	# Música al 65% (0 dB = 100%).
	bgm_player.volume_db = linear_to_db(0.5)
	# La pausa del juego (árbol pausado) no debe interrumpir la música.
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player)
	# Reanudar en bucle cuando el track finaliza.
	bgm_player.finished.connect(_on_bgm_finished)

	# 2. Leemos el estado persistente guardado en save_manager
	music_enabled = save_manager.obtener_opcion_audio("music_enabled", true)
	sfx_enabled = save_manager.obtener_opcion_audio("sfx_enabled", true)


# ==========================================
# GESTIÓN DE MÚSICA DE FONDO (BGM)
# ==========================================

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	save_manager.guardar_opcion_audio("music_enabled", enabled) # Guarda en el JSON

	if bgm_player == null or bgm_player.stream == null:
		return

	if enabled:
		bgm_player.stream_paused = false
		if not bgm_player.playing:
			bgm_player.play()
	else:
		bgm_player.stream_paused = true

## Asegura que suene el tema de title/options.
## Si ya está sonando, no lo reinicia (continuidad title <-> options).
## Si la música está desactivada, lo deja preparado pero pausado.
func ensure_title_bgm() -> void:
	_activar_bgm(TITLE_BGM)

## Asegura que suene el theme del minijuego indicado (por defecto el actual).
## Corta main_theme al entrar al juego; suena en selección de niveles y en partida.
## Si ya está sonando, no lo reinicia. Sin theme para el id: no toca lo que suena.
func ensure_game_bgm(id_juego: String = "") -> void:
	if id_juego == "":
		id_juego = save_manager.juego_actual_seleccionado
	var theme := _obtener_theme(id_juego)
	if theme == null:
		return
	_activar_bgm(theme)

func _obtener_theme(id_juego: String) -> AudioStream:
	if not THEME_PATHS.has(id_juego):
		return null
	if _theme_cache.has(id_juego):
		return _theme_cache[id_juego] as AudioStream
	var ruta: String = str(THEME_PATHS[id_juego])
	if not ResourceLoader.exists(ruta):
		push_warning("AudioManager: sin theme para juego '%s' (%s)" % [id_juego, ruta])
		return null
	var stream := load(ruta) as AudioStream
	if stream != null:
		_theme_cache[id_juego] = stream
	return stream

func _activar_bgm(stream: AudioStream) -> void:
	if bgm_player == null or stream == null:
		return
	if bgm_player.stream != stream:
		bgm_player.stream = stream
		bgm_player.stream_paused = false
		if music_enabled:
			bgm_player.play()
		return
	if music_enabled:
		bgm_player.stream_paused = false
		if not bgm_player.playing:
			bgm_player.play()
	else:
		bgm_player.stream_paused = true

func _on_bgm_finished() -> void:
	# Bucle: al finalizar el track, comenzar otra vez (solo si la música está activada).
	if bgm_player == null or bgm_player.stream == null:
		return
	if music_enabled:
		bgm_player.play()

func play_bgm(stream: AudioStream) -> void:
	if stream == null:
		return

	bgm_player.stream = stream
	bgm_player.stream_paused = false
	if music_enabled:
		bgm_player.play()


# ==========================================
# GESTIÓN DE EFECTOS DE SONIDO (SFX)
# ==========================================

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	save_manager.guardar_opcion_audio("sfx_enabled", enabled) # Guarda en el JSON

func play_start() -> void:
	if sfx_enabled and start:
		start.play()

func play_welldone() -> void:
	if sfx_enabled and welldone:
		welldone.play()

func play_prize() -> void:
	if sfx_enabled and prize:
		prize.play()

func play_ok1() -> void:
	if sfx_enabled and ok1:
		ok1.play()

func play_pop() -> void:
	if sfx_enabled and pop:
		pop.play()

func play_fail() -> void:
	if sfx_enabled and fail1:
		fail1.play()
