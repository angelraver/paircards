extends RigidBody3D

# Configuración de oscilación superior
var is_active: bool = false
var sweep_speed: float = 2.5
var min_x: float = -0.8
var max_x: float = 0.8
var spawn_y: float = 1.3

var time_passed: float = 0.0

# --- Audio: patrón GameAudioBase (ver games/tincanalley/scripts/lata.gd y core/scripts/game_audio_base.gd) ---
var audio: GameAudioBase
@export var umbral_velocidad: float = 0.8
@export var tiempo_cooldown: float = 0.08
var puede_sonar: bool = true

func _ready() -> void:
	# Congelar la física inicialmente para que no caiga
	freeze = true
	position = Vector3(0.0, spawn_y, 0.2)

	# Habilita detección de colisiones para reproducir sonido pik
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(_cuerpo: Node) -> void:
	if not is_active:
		return
	if not puede_sonar:
		return
	if linear_velocity.length() < umbral_velocidad:
		return
	puede_sonar = false
	if audio:
		audio.play_pik()
	get_tree().create_timer(tiempo_cooldown).timeout.connect(
		func():
			if is_instance_valid(self):
				puede_sonar = true
	)

func _process(delta: float) -> void:
	if not is_active:
		time_passed += delta * sweep_speed
		# Movimiento suavizado de lado a lado usando Seno (-1 a 1)
		var ping_pong: float = (sin(time_passed) + 1.0) / 2.0 # Normalizado entre 0 y 1
		var current_x: float = lerp(min_x, max_x, ping_pong)
		position = Vector3(current_x, spawn_y, 0.2)

func release_ball() -> void:
	if not is_active:
		is_active = true
		freeze = false # Activa la gravedad y la física 3D
		# Le damos un pequeño impulso aleatorio o nulo hacia abajo
		linear_velocity = Vector3(0.0, -0.5, 0.0)
