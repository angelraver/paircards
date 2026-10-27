extends Node3D

const MAX_BALLS: int = 5

@export_file("*.json") var ruta_niveles_json: String = "res://data/niveles.json"
@export var board_frame_scene: PackedScene = preload("res://scenes/board_frame.tscn")
@export var peg_scene: PackedScene = preload("res://scenes/peg.tscn")
@export var ramp_scene: PackedScene = preload("res://scenes/ramp.tscn")
@export var slot_scene: PackedScene = preload("res://scenes/slot.tscn")
@export var divider_scene: PackedScene = preload("res://scenes/divider.tscn")
@export var nivel_actual: int = 1

# Nodos contenedores y cámara
@onready var board_frame_holder: Node3D = $BoardFrameHolder
@onready var board_elements: Node3D = $BoardElements
@onready var camera: Camera3D = $Camera3D
@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego
@onready var boton_pausa: TextureButton = $UI/BotonPausa
@onready var panel_pausa: PanelPausa = $UI/PanelPausa as PanelPausa
@onready var bola_ui_3d: Node3D = $UI/ContenedorBolasUI/SubViewportContainer/SubViewport/BolaUI
@onready var ui_label_bolas: Label = $UI/ContenedorBolasUI/LabelBolas
@onready var contenedor_bolas_ui: Control = $UI/ContenedorBolasUI

var puntaje_nivel: int = 0
var puntaje_maximo_nivel: int = 0
# Compatibilidad: alias legacy 'score' usado en prints previos
var score: int:
	get: return puntaje_nivel
	set(value): puntaje_nivel = value

var cols: int = 10
var rows: int = 12
var cell_size: float = 0.2

var ball_scene: PackedScene = preload("res://scenes/ball.tscn")
var current_ball: RigidBody3D = null
var balls_launched: int = 0
var active_balls: Array[RigidBody3D] = []
var game_ended: bool = false
var ctrl_resultados: ControladorResultados
var tiempo_bolas_quietas: float = 0.0
const UMBRAL_QUIETUD: float = 0.1
const TIEMPO_QUIETO_REQUERIDO: float = 0.5 # >0.4s de slot.gd para asegurar puntuación definitiva

func _ready() -> void:
	audio_manager.ensure_game_bgm("plinko")
	nivel_actual = save_manager.nivel_actual_seleccionado

	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	var hud: Array = [ui_puntaje, ui_level_number, boton_pausa, contenedor_bolas_ui]
	ctrl_resultados.configurar(panel_resultados, hud, ui_puntaje, ui_level_number, reiniciar_nivel)

	if boton_pausa and not boton_pausa.is_connected("pressed", _on_boton_pausa_pressed):
		boton_pausa.pressed.connect(_on_boton_pausa_pressed)

	cargar_nivel(nivel_actual)

func _process(delta: float) -> void:
	if bola_ui_3d:
		bola_ui_3d.rotate_y(delta * 1.5)
	if game_ended:
		return
	# Condición 1: que no queden bolas por arrojar. Ocurre siempre antes que la 2.
	if balls_launched < MAX_BALLS:
		tiempo_bolas_quietas = 0.0
		return
	# Condición 1 cumplida (todas usadas). Evaluar condición 2: todas quietas.
	if _todas_bolas_quietas():
		tiempo_bolas_quietas += delta
		if tiempo_bolas_quietas >= TIEMPO_QUIETO_REQUERIDO:
			game_ended = true
			mostrar_panel_resultados()
	else:
		tiempo_bolas_quietas = 0.0

func _todas_bolas_quietas() -> bool:
	# Debe haber tantas bolas activas como lanzadas y ninguna en vuelo
	if active_balls.size() != MAX_BALLS:
		return false
	if active_balls.is_empty():
		return false
	for ball in active_balls:
		if not is_instance_valid(ball):
			return false
		# Velocity instantánea < umbral (misma métrica que slot.gd:64)
		if ball.linear_velocity.length() > UMBRAL_QUIETUD or ball.angular_velocity.length() > UMBRAL_QUIETUD:
			return false
		# Opcional: si la bola aún no ha sido puntuada, no considerarla definitiva
		# Slot marca ball.set("scored", true) tras 0.4s quieta dentro del slot.
		# Si queremos asegurar puntuación definitiva, exigir scored == true:
		# if ball.get("scored") != true: return false
	return true

func cargar_nivel(numero_nivel: int) -> void:
	ctrl_resultados.reset()

	print("generate level!")
	clear_board()
	puntaje_nivel = 0
	puntaje_maximo_nivel = 0
	balls_launched = 0
	active_balls.clear()
	game_ended = false
	tiempo_bolas_quietas = 0.0
	if current_ball and is_instance_valid(current_ball):
		current_ball.queue_free()
		current_ball = null

	actualizar_ui_puntaje()
	actualizar_ui_level()
	actualizar_ui_bolas()

	if not FileAccess.file_exists(ruta_niveles_json):
		return

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var datos_niveles = JSON.parse_string(texto_json)
	if not datos_niveles or not datos_niveles.has(str(numero_nivel)):
		return

	var level_data = datos_niveles[str(numero_nivel)]

	# Puntaje máximo del nivel (meta para PanelResultados). Soporta claves legacy.
	puntaje_maximo_nivel = int(level_data.get("puntaje", level_data.get("meta_puntos", 1000)))
	actualizar_ui_puntaje()
	actualizar_ui_maximo()
	actualizar_ui_level()
	actualizar_ui_bolas()

	var peg_color_hex: String = level_data.get("color_peg", "ff00ff")
	var board_color_hex: String = level_data.get("color_board", "ffff00")
	var ramp_color_hex: String = level_data.get("color_ramp", peg_color_hex)

	# Soporte para niveles legacy con grid_cols/grid_rows/cell_size
	if level_data.has("grid_cols"):
		cols = level_data.get("grid_cols")
	if level_data.has("grid_rows"):
		rows = level_data.get("grid_rows")
	if level_data.has("cell_size"):
		cell_size = level_data.get("cell_size")

	if board_frame_scene:
		var frame_inst = board_frame_scene.instantiate()
		board_frame_holder.add_child(frame_inst)

		_apply_element_color(frame_inst, board_color_hex)

	var pegs_array = level_data.get("pegs", [])
	for peg_info in pegs_array:
		var peg_col: float = float(peg_info["x"])
		var peg_row: int = peg_info["y"]
		
		var peg_inst = peg_scene.instantiate()
		board_elements.add_child(peg_inst)
		peg_inst.position = grid_to_world(peg_col, peg_row)

		_apply_element_color(peg_inst, peg_color_hex)

	var ramps_array = level_data.get("ramps", [])
	for ramp_info in ramps_array:
		var ramp_col: float = float(ramp_info["x"])
		var ramp_row: float = float(ramp_info["y"])
		var rot_deg: float = ramp_info.get("rot", 0.0)
		
		var ramp_inst = ramp_scene.instantiate()
		board_elements.add_child(ramp_inst)
		ramp_inst.position = grid_to_world(ramp_col, ramp_row)
		ramp_inst.rotation_degrees.z = rot_deg

		_apply_element_color(ramp_inst, ramp_color_hex)

	var slots_array = level_data.get("slots", [])
	build_slots(slots_array)

	anunciar_nivel(numero_nivel)
	setup_camera()

func build_slots(slots_data: Array) -> void:
	var row_y: float = -2.8 # Fila donde se instancian los sensores
	
	for i in range(slots_data.size()):
		var slot_info = slots_data[i]
		var col_start: float = float(slot_info["x_start"])
		var col_end: float = float(slot_info["x_end"])
		var pts: int = int(slot_info["pts"])
		var color_hex: String = slot_info.get("color", "#FF0000") # Rojo por defecto si falta en JSON

		# 1. Calcular el ancho total del slot en unidades de mundo
		var total_cols_span: float = col_end - col_start
		var slot_width_world: float = total_cols_span * cell_size

		# 2. Posición central del slot
		var mid_col: float = (col_start + col_end) / 2.0
		var slot_inst = slot_scene.instantiate()
		slot_inst.points = pts
		slot_inst.position = grid_to_world(mid_col, row_y)
		
		# 3. Ajustamos el ancho dinámicamente ANTES de añadirlo a la escena
		slot_inst.setup_slot(slot_width_world, pts, color_hex)
		
		slot_inst.ball_scored.connect(_on_ball_scored)
		board_elements.add_child(slot_inst)

		# 4. Instanciar divisores (Dividers) en col_start y col_end
		var divider_inst = divider_scene.instantiate()
		divider_inst.position = grid_to_world(col_start, row_y)
		board_elements.add_child(divider_inst)

		if i == slots_data.size() - 1:
			var last_divider = divider_scene.instantiate()
			last_divider.position = grid_to_world(col_end, row_y)
			board_elements.add_child(last_divider)

func _on_ball_scored(points_awarded: int, _ball_node: Node = null) -> void:
	puntaje_nivel += points_awarded
	actualizar_ui_puntaje()
	if audio_juego:
		audio_juego.play_points()
	if _ball_node:
		EfectosUI.crear_efecto_puntos((_ball_node as Node3D).global_position, points_awarded)
	print("¡Goles/Puntos anotados!: ", points_awarded, " | Puntaje Total: ", puntaje_nivel)

func actualizar_ui_puntaje() -> void:
	ctrl_resultados.actualizar_puntaje(puntaje_nivel)

func actualizar_ui_maximo() -> void:
	ctrl_resultados.actualizar_maximo(puntaje_maximo_nivel)

func actualizar_ui_level() -> void:
	ctrl_resultados.actualizar_nivel(nivel_actual)

func actualizar_ui_bolas() -> void:
	if ui_label_bolas:
		ui_label_bolas.text = "x %d" % maxi(0, MAX_BALLS - balls_launched)

func mostrar_panel_resultados() -> void:
	ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)

func _on_boton_pausa_pressed() -> void:
	# No abrir la pausa si ya terminó el nivel y se ven los resultados
	if panel_resultados and panel_resultados.visible:
		return
	if panel_pausa == null:
		return
	if panel_pausa.visible:
		return
	audio_manager.play_ok1()
	panel_pausa.mostrar()

func reiniciar_nivel() -> void:
	for ball in active_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	active_balls.clear()
	if current_ball and is_instance_valid(current_ball):
		current_ball.queue_free()
		current_ball = null
	cargar_nivel(nivel_actual)
	spawn_next_ball()

func setup_camera() -> void:
	var total_width_cam: float = cols * cell_size
	var total_height_cam: float = rows * cell_size

	var max_dimension_cam: float = max(total_width_cam, total_height_cam)
	var distance_z: float = max_dimension_cam * 1.4

	# 1. Posición y rotación de destino (vista normal de juego)
	var final_position: Vector3 = Vector3(0.0, 0.0, distance_z)
	var final_rotation: Vector3 = Vector3.ZERO

	# 2. Estado inicial: Cerca del tablero (ej. 30% de la distancia final) y dada vuelta en Z (180°)
	camera.position = Vector3(0.0, 0.0, distance_z * 0.2)
	camera.rotation_degrees = Vector3(0.0, 0.0, 180.0)

	# 3. Animar posición y rotación en paralelo
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "position", final_position, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "rotation_degrees", final_rotation, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 4. Cuando finaliza la transición, spawneamos la primera bola
	tween.chain().tween_callback(spawn_next_ball)

func grid_to_world(col_pos: float, row_pos: float) -> Vector3:
	var total_width_grid: float = cols * cell_size
	var total_height_grid: float = rows * cell_size

	var start_x: float = -(total_width_grid / 2.0) + (cell_size / 2.0)
	var start_y: float = -(total_height_grid / 2.0) + (cell_size / 2.0)

	var x_pos: float = start_x + (col_pos * cell_size)
	var y_pos: float = start_y + (row_pos * cell_size)
	var z_pos: float = 0.2

	return Vector3(x_pos, y_pos, z_pos)

func _apply_element_color(node: Node, color_hex: String) -> void:
	# API genérica unificada: todos los elementos (board, peg, ramp) exponen set_element_color
	# que internamente delega a ColorUtils.apply_color. Fallback directo por si el nodo no
	# tiene el método (p.ej. escena sin script).
	if node.has_method("set_element_color"):
		node.call("set_element_color", color_hex)
	elif node.has_method("set_board_color"):
		node.call("set_board_color", color_hex)
	elif node.has_method("set_peg_color"):
		node.call("set_peg_color", color_hex)
	elif node.has_method("set_ramp_color"):
		node.call("set_ramp_color", color_hex)
	else:
		ColorUtils.apply_color(node, color_hex)

func anunciar_nivel(numero_nivel: int) -> void:
	if not ui_level_title:
		return
	ui_level_title.text = game_manager.obtener_titulo_nivel(str(numero_nivel))
	ui_level_title.modulate.a = 1.0
	ui_level_title.visible = true
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(ui_level_title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): ui_level_title.visible = false)

func clear_board() -> void:
	for child in board_frame_holder.get_children():
		child.queue_free()
	for child in board_elements.get_children():
		child.queue_free()

func load_level_data(level_id: String) -> Dictionary:
	# Compatibilidad: wrapper legacy que ahora usa ruta_niveles_json y get_file_as_string
	if not FileAccess.file_exists(ruta_niveles_json):
		print("ERROR: No existe el archivo de niveles")
		return {}

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var parsed_result = JSON.parse_string(texto_json)
	
	if parsed_result == null or not parsed_result.has(level_id):
		return {}

	return parsed_result[level_id]

func spawn_next_ball() -> void:
	if balls_launched >= MAX_BALLS:
		return
	if game_ended or ctrl_resultados.esta_mostrado():
		return

	if current_ball == null:
		current_ball = ball_scene.instantiate()
		
		# Inyección de audio: patrón GameAudioBase (ver games/tincanalley/scripts/main.gd:141 y games/tincanalley/scripts/lata.gd:7)
		# Usa set() para evitar error de tipado estático (current_ball es RigidBody3D pero el script define var audio)
		if audio_juego:
			current_ball.set("audio", audio_juego)
		
		# Calculamos los límites superiores basados en el tamaño del tablero
		var board_width: float = cols * cell_size
		var board_height: float = rows * cell_size + 0.5
		
		# Ajustar el barrido horizontal dentro de los límites de las paredes
		current_ball.min_x = -(board_width / 2.0) + 0.15
		current_ball.max_x = (board_width / 2.0) - 0.15
		# Posicionarla justo por arriba de la primera fila de pilones
		current_ball.spawn_y = (board_height / 2.0) + 0.1
		
		add_child(current_ball)
		
func _unhandled_input(event: InputEvent) -> void:
	if game_ended or ctrl_resultados.esta_mostrado():
		return
	# Detectar clic de mouse o tap en pantalla táctil
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_ball != null and not current_ball.is_active:
			current_ball.release_ball()
			balls_launched += 1
			actualizar_ui_bolas()
			active_balls.append(current_ball)
			current_ball = null
			
			# Esperar 1 segundo tras el lanzamiento para instanciar la siguiente bola (si quedan disponibles)
			if balls_launched < MAX_BALLS:
				get_tree().create_timer(1.0).timeout.connect(spawn_next_ball)
