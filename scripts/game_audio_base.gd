class_name GameAudioBase
extends Node

var grupos_sonido: Dictionary = {}

func _ready() -> void:
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
	return save_manager.obtener_opcion_audio("sfx_enabled", true)

func play(prefijo: String) -> void:
	if not sfx_habilitado():
		return
	var players: Array = grupos_sonido.get(prefijo, [])
	if not players.is_empty():
		players[0].play()

func play_aleatorio(prefijo: String) -> void:
	if not sfx_habilitado():
		return
	var players: Array = grupos_sonido.get(prefijo, [])
	if not players.is_empty():
		players.pick_random().play()
