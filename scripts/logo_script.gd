extends Control

const TITLE_SCENE = "res://scenes/title.tscn"

@onready var mat = material as ShaderMaterial
@export var wait_time: float = 3.0
@export var duracion_dissolve: float = 1.5
@onready var sonido_transicion = $"../../AudioStreamPlayer2D"

var ya_inicio: bool = false
var tween_actual: Tween
var timer_auto: SceneTreeTimer

func _process(delta: float) -> void:
	if mat:
		var current_time = mat.get_shader_parameter("u_time")
		mat.set_shader_parameter("u_time", current_time + delta)
	
# Función para iniciar la animación de entrada
func play_intro() -> void:
	if mat:
		# Arranca oculto y se disuelve hasta mostrarse completo
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/u_dissolve_amount", 1.0, 1.5).from(1.0)
		
# Detecta cuando el usuario hace Tap en el celular o Clic de Mouse
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		forzar_transicion()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		forzar_transicion()

func forzar_transicion() -> void:
	if ya_inicio:
		return
	disolver_y_cambiar()

func disolver_y_cambiar() -> void:
	if ya_inicio:
		return
	ya_inicio = true

	if mat:
		if tween_actual and tween_actual.is_running():
			tween_actual.kill()
		
		sonido_transicion.play()
		
		tween_actual = create_tween()
		tween_actual.tween_property(mat, "shader_parameter/u_dissolve_amount", 0.0, duracion_dissolve)
		await tween_actual.finished

	get_tree().change_scene_to_file(TITLE_SCENE)
	
func init_transition() -> void:
	# Espera N segundos
	await get_tree().create_timer(wait_time).timeout
	
	sonido_transicion.play()
	
	# Opcional: Podés hacer un fade out del dissolve antes de cambiar
	if mat:
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/u_dissolve_amount", 0.0, duracion_dissolve)
		await tween.finished
	
	# Cambia a la escena que tenías antes
	get_tree().change_scene_to_file(TITLE_SCENE)

func _on_timer_timeout() -> void:
	if not ya_inicio:
		ejecutar_dissolve()

func ejecutar_dissolve() -> void:
	if ya_inicio:
		return
	ya_inicio = true

	if mat:
		if tween_actual and tween_actual.is_running():
			tween_actual.kill()
		
		# Inicia el Tween instantáneamente en este mismo frame
		tween_actual = create_tween()
		tween_actual.tween_property(mat, "shader_parameter/u_dissolve_amount", 0.0, duracion_dissolve)
		tween_actual.finished.connect(_cambiar_escena)
	else:
		_cambiar_escena()

func _cambiar_escena() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
	
func _ready() -> void:
	if mat:
		# En el shader original, 1.0 es el logo COMPLETO
		mat.set_shader_parameter("u_dissolve_amount", 1.0)

	# Habilita la detección de clicks/taps si el TextureRect no los captura
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	timer_auto = get_tree().create_timer(wait_time)
	timer_auto.timeout.connect(_on_timer_timeout)

	play_intro()
	init_transition()
