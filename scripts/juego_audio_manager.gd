class_name juego_audio_manager
extends GameAudioBase

const DROP_PATHS := {
	"Drop1": "res://assets/sounds/drop1.wav",
	"Drop2": "res://assets/sounds/drop2.wav",
	"Drop3": "res://assets/sounds/drop3.wav",
	"Drop4": "res://assets/sounds/drop4.wav",
}

const SELECT_PATH := "res://assets/sounds/select.wav"
const SELECTED_PATH := "res://assets/sounds/selected.wav"

func _ready() -> void:
	# Agregar AudioStreamPlayer para los sonidos de drop por código
	for nombre in DROP_PATHS.keys():
		var player := AudioStreamPlayer.new()
		player.name = nombre
		player.stream = load(DROP_PATHS[nombre])
		add_child(player)
	# Agregar AudioStreamPlayer para select
	var player_select := AudioStreamPlayer.new()
	player_select.name = "Select"
	player_select.stream = load(SELECT_PATH)
	add_child(player_select)
	# Re-agrupar sonidos después de agregar los players
	_reagrupar_sonidos()

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

func play_drop() -> void:
	play_aleatorio("Drop")

func play_select() -> void:
	play("Select")

func play_selected() -> void:
	play("Selected")
