class_name SeleccionNiveles
extends Control

enum DireccionScroll { ABAJO_ARRIBA, ARRIBA_ABAJO }

signal level_selected(level_number: int)

const ANCHO_BASE_CHUNK: float = 557.0
const ALTO_BASE_CHUNK: float = 842.0
const PUNTERO_NINGUNO: int = -2
const PUNTERO_RATON: int = -1
const ESCENA_CHUNK: PackedScene = preload("res://scenes/level_sequence_chunk.tscn")

@export var total_sequences: int = 3
@export var initial_sequence_index: int = 0
@export var base_step_y: float = 159.17
@export var direccion_scroll: DireccionScroll = DireccionScroll.ABAJO_ARRIBA
@export var friction: float = 5.0
@export var bounce_stiffness: float = 22.0
@export var bounce_damping: float = 10.0
@export var rubber_band: float = 0.28
@export var max_velocity: float = 2400.0
@export var drag_sensitivity: float = 1.0
@export var tap_tolerance_px: float = 12.0
@export var velocity_smoothing: float = 0.45
@export var top_margin: float = 24.0
@export var bottom_margin: float = 24.0

@onready var content_container: Control = $ContentContainer

var _chunks: Array[LevelSequenceChunk] = []
var _scale_factor: float = 1.0
var _step_y: float = 0.0
var _chunk_height: float = 0.0
var _limite_inferior: float = 0.0
var _limite_superior: float = 0.0
var _velocidad_y: float = 0.0
var _puntero_activo: int = PUNTERO_NINGUNO
var _ultima_y_puntero: float = 0.0
var _ultimo_movimiento_ms: int = 0
var _distancia_arrastre: float = 0.0
var _tap_bloqueado: bool = false
var _layout_inicializado: bool = false


func _ready() -> void:
	_recalcular_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and content_container != null:
		_recalcular_layout()


func _process(delta: float) -> void:
	if content_container == null:
		return

	if _puntero_activo != PUNTERO_NINGUNO:
		if Time.get_ticks_msec() - _ultimo_movimiento_ms > 90:
			_velocidad_y = 0.0
		return

	var paso: float = minf(delta, 0.05)
	var exceso: float = _calcular_exceso(content_container.position.y)
	if absf(exceso) > 0.01:
		var aceleracion: float = -bounce_stiffness * exceso - bounce_damping * _velocidad_y
		_velocidad_y += aceleracion * paso
	else:
		_velocidad_y *= exp(-friction * paso)
		if absf(_velocidad_y) < 1.0:
			_velocidad_y = 0.0

	_velocidad_y = clampf(_velocidad_y, -max_velocity, max_velocity)
	if is_zero_approx(_velocidad_y):
		return

	content_container.position.y += _velocidad_y * paso
	var nuevo_exceso: float = _calcular_exceso(content_container.position.y)
	if absf(nuevo_exceso) < 0.5 and absf(_velocidad_y) < 40.0:
		content_container.position.y = clampf(content_container.position.y, _limite_inferior, _limite_superior)
		_velocidad_y = 0.0


func _input(event: InputEvent) -> void:
	if content_container == null:
		return

	if event is InputEventScreenTouch:
		var toc: InputEventScreenTouch = event as InputEventScreenTouch
		if toc.pressed:
			if _puntero_activo == PUNTERO_NINGUNO:
				_iniciar_arrastre(toc.index, toc.position.y)
		elif toc.index == _puntero_activo:
			_terminar_arrastre()
		return

	if event is InputEventScreenDrag:
		var arrastre: InputEventScreenDrag = event as InputEventScreenDrag
		if arrastre.index == _puntero_activo:
			_registrar_movimiento(arrastre.relative.length())
			_actualizar_arrastre(arrastre.position.y)
		return

	if event is InputEventMouseButton:
		var boton: InputEventMouseButton = event as InputEventMouseButton
		if boton.button_index != MOUSE_BUTTON_LEFT:
			return
		if boton.pressed:
			if _puntero_activo == PUNTERO_NINGUNO:
				_iniciar_arrastre(PUNTERO_RATON, boton.position.y)
		elif _puntero_activo == PUNTERO_RATON:
			_terminar_arrastre()
		return

	if event is InputEventMouseMotion and _puntero_activo == PUNTERO_RATON:
		var movimiento: InputEventMouseMotion = event as InputEventMouseMotion
		_registrar_movimiento(movimiento.relative.length())
		_actualizar_arrastre(movimiento.position.y)


func _iniciar_arrastre(id_puntero: int, y_puntero: float) -> void:
	_puntero_activo = id_puntero
	_ultima_y_puntero = y_puntero
	_ultimo_movimiento_ms = Time.get_ticks_msec()
	_velocidad_y = 0.0
	_distancia_arrastre = 0.0
	_tap_bloqueado = false


func _registrar_movimiento(distancia: float) -> void:
	_distancia_arrastre += maxf(distancia, 0.0)
	if _distancia_arrastre > maxf(tap_tolerance_px, 0.0):
		_tap_bloqueado = true


func _actualizar_arrastre(y_puntero: float) -> void:
	if content_container == null:
		return

	var ahora_ms: int = Time.get_ticks_msec()
	var delta_segundos: float = float(ahora_ms - _ultimo_movimiento_ms) / 1000.0
	var delta_puntero: float = y_puntero - _ultima_y_puntero
	var posicion_actual: float = content_container.position.y
	var destino: float = posicion_actual + delta_puntero * drag_sensitivity
	var nueva_posicion: float = _aplicar_resistencia(posicion_actual, destino)

	content_container.position.y = nueva_posicion
	if delta_segundos > 0.0:
		var velocidad_instantanea: float = (nueva_posicion - posicion_actual) / delta_segundos
		_velocidad_y = lerpf(_velocidad_y, velocidad_instantanea, clampf(velocity_smoothing, 0.0, 1.0))

	_ultima_y_puntero = y_puntero
	_ultimo_movimiento_ms = ahora_ms


func _terminar_arrastre() -> void:
	_puntero_activo = PUNTERO_NINGUNO
	if Time.get_ticks_msec() - _ultimo_movimiento_ms > 90:
		_velocidad_y = 0.0
	_velocidad_y = clampf(_velocidad_y, -max_velocity, max_velocity)


func _aplicar_resistencia(actual: float, destino: float) -> float:
	var resistencia: float = clampf(rubber_band, 0.0, 1.0)
	if actual < _limite_inferior:
		if destino <= actual:
			return actual + (destino - actual) * resistencia
		if destino > _limite_superior:
			return _limite_superior + (destino - _limite_superior) * resistencia
		return destino
	if actual > _limite_superior:
		if destino >= actual:
			return actual + (destino - actual) * resistencia
		if destino < _limite_inferior:
			return _limite_inferior + (destino - _limite_inferior) * resistencia
		return destino
	if destino < _limite_inferior:
		return _limite_inferior + (destino - _limite_inferior) * resistencia
	if destino > _limite_superior:
		return _limite_superior + (destino - _limite_superior) * resistencia
	return destino


func _calcular_exceso(y: float) -> float:
	if y < _limite_inferior:
		return y - _limite_inferior
	if y > _limite_superior:
		return y - _limite_superior
	return 0.0


func _recalcular_layout() -> void:
	if content_container == null:
		return

	var tam_viewport: Vector2 = get_viewport_rect().size
	_scale_factor = maxf(tam_viewport.x / ANCHO_BASE_CHUNK, 0.01)
	_chunk_height = ALTO_BASE_CHUNK * _scale_factor
	var solapamiento: float = clampf(base_step_y, 0.0, ALTO_BASE_CHUNK - 1.0) * _scale_factor
	_step_y = maxf(_chunk_height - solapamiento, 1.0)

	var cantidad: int = maxi(1, total_sequences)
	_asegurar_chunks(cantidad)
	_posicionar_chunks(cantidad, tam_viewport.x)
	_calcular_limites(cantidad, tam_viewport.y)

	if not _layout_inicializado:
		content_container.position.y = clampf(_posicion_inicial(initial_sequence_index, cantidad), _limite_inferior, _limite_superior)
		_layout_inicializado = true
	else:
		content_container.position.y = clampf(content_container.position.y, _limite_inferior, _limite_superior)


func _asegurar_chunks(cantidad: int) -> void:
	while _chunks.size() < cantidad:
		var chunk: LevelSequenceChunk = ESCENA_CHUNK.instantiate() as LevelSequenceChunk
		if chunk == null:
			return
		content_container.add_child(chunk)
		if not chunk.level_selected.is_connected(_on_nivel_seleccionado):
			chunk.level_selected.connect(_on_nivel_seleccionado)
		_chunks.append(chunk)

	while _chunks.size() > cantidad:
		var sobrante: LevelSequenceChunk = _chunks.pop_back() as LevelSequenceChunk
		if sobrante != null:
			sobrante.queue_free()


func _posicionar_chunks(cantidad: int, ancho_viewport: float) -> void:
	var x_chunk: float = (ancho_viewport - ANCHO_BASE_CHUNK * _scale_factor) * 0.5
	for i in range(cantidad):
		var chunk: LevelSequenceChunk = _chunks[i]
		var primer_nivel: int = i * LevelSequenceChunk.NIVELES_NETOS + 1
		chunk.configurar(i, _scale_factor, primer_nivel, i > 0)
		chunk.position = Vector2(x_chunk, _posicion_local(i))


func _posicion_local(indice: int) -> float:
	var desplazamiento: float = float(indice) * _step_y
	if direccion_scroll == DireccionScroll.ABAJO_ARRIBA:
		return -desplazamiento
	return desplazamiento


func _calcular_limites(cantidad: int, alto_viewport: float) -> void:
	var margen_superior: float = maxf(top_margin, 0.0)
	var margen_inferior: float = maxf(bottom_margin, 0.0)
	var min_local: float = 0.0
	var max_local: float = _chunk_height

	if direccion_scroll == DireccionScroll.ABAJO_ARRIBA:
		min_local = -float(cantidad - 1) * _step_y
	else:
		max_local += float(cantidad - 1) * _step_y

	_limite_inferior = alto_viewport - margen_inferior - max_local
	_limite_superior = margen_superior - min_local
	if _limite_inferior > _limite_superior:
		var centro: float = (_limite_inferior + _limite_superior) * 0.5
		_limite_inferior = centro
		_limite_superior = centro


func _posicion_inicial(indice: int, cantidad: int) -> float:
	var indice_valido: int = clampi(indice, 0, maxi(1, cantidad) - 1)
	var y_local: float = _posicion_local(indice_valido)
	if direccion_scroll == DireccionScroll.ABAJO_ARRIBA:
		return _limite_inferior - y_local
	return _limite_superior - y_local


func _on_nivel_seleccionado(numero_nivel: int) -> void:
	if _tap_bloqueado:
		return

	save_manager.nivel_actual_seleccionado = numero_nivel
	audio_manager.play_ok1()
	level_selected.emit(numero_nivel)

	var config: Dictionary = game_manager.obtener_config_juego_actual() as Dictionary
	var escena_destino: String = str(config.get("escena_juego", ""))
	if escena_destino != "" and ResourceLoader.exists(escena_destino):
		get_tree().change_scene_to_file(escena_destino)
