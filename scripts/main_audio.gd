class_name MainAudio
extends Node

const DROP_PATHS := {
	"Drop1": "res://assets/sounds/drop1.wav",
	"Drop2": "res://assets/sounds/drop2.wav",
	"Drop3": "res://assets/sounds/drop3.wav",
	"Drop4": "res://assets/sounds/drop4.wav",
}
const SELECT_PATH := "res://assets/sounds/select.wav"
const SELECTED_PATH := "res://assets/sounds/selected.wav"

var grupos_sonido: Dictionary = {}


func _ready() -> void:
	_crear_players_dinamicos()
	_reagrupar_sonidos()


func _crear_players_dinamicos() -> void:
	for nombre in DROP_PATHS.keys():
		_crear_player(String(nombre), String(DROP_PATHS[nombre]))
	_crear_player("Select", SELECT_PATH)
	_crear_player("Selected", SELECTED_PATH)


func _crear_player(nombre: String, ruta: String) -> void:
	var stream := load(ruta) as AudioStream
	if stream == null:
		push_warning("MainAudio: no se pudo cargar '%s'" % ruta)
		return
	var player := AudioStreamPlayer.new()
	player.name = nombre
	player.stream = stream
	add_child(player)


func _reagrupar_sonidos() -> void:
	grupos_sonido.clear()
	for hijo in get_children():
		if hijo is AudioStreamPlayer:
			var prefijo := _prefijo_nombre(hijo.name)
			if prefijo.is_empty():
				continue
			if not grupos_sonido.has(prefijo):
				grupos_sonido[prefijo] = []
			grupos_sonido[prefijo].append(hijo)


func _prefijo_nombre(nombre: StringName) -> String:
	var texto := String(nombre)
	var fin := 0
	while fin < texto.length() and not (texto[fin] >= "0" and texto[fin] <= "9"):
		fin += 1
	return texto.substr(0, fin)


func sfx_habilitado() -> bool:
	return audio_manager.sfx_enabled


func play(prefijo: String) -> void:
	if not sfx_habilitado():
		return
	var players: Array = grupos_sonido.get(prefijo, []) as Array
	if not players.is_empty():
		var player := players[0] as AudioStreamPlayer
		if player != null:
			player.play()


func play_aleatorio(prefijo: String) -> void:
	if not sfx_habilitado():
		return
	var players: Array = grupos_sonido.get(prefijo, []) as Array
	if not players.is_empty():
		var player := players.pick_random() as AudioStreamPlayer
		if player != null:
			player.play()


func play_drop() -> void:
	play_aleatorio("Drop")


func play_select() -> void:
	play("Select")


func play_selected() -> void:
	play("Selected")
