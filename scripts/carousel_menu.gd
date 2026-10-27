class_name CarouselMenu
extends Control
## Carrusel cilíndrico para elegir minijuego en la pantalla de título.
##
## Uso:
##   carousel.setup_carousel([
##     {"id": "tincanalley", "title": "Tin Can Alley", "texture": preload(...)},
##     ...
##   ])
##   carousel.item_selected.connect(_on_game_selected)
##   carousel.focused_item_changed.connect(_on_game_focused)
##
## - Arrastrar con dedo/mouse rota con inercia y hace snap al logo central.
## - Tocar el logo central emite [signal item_selected].
## - Tocar un logo lateral gira hacia él (no lo abre directamente).
## - Teclado: ui_left/ui_right mueven el foco, ui_accept abre el central.

signal item_selected(item_id: String)
signal focused_item_changed(index: int, item_id: String)

@export_category("Configuración del Carrusel")
@export var item_size: Vector2 = Vector2(320, 320)
@export var radius_x: float = 300.0
@export var arc_height: float = 40.0 ## Desplazamiento vertical de los laterales (efecto arco).
@export var scale_min: float = 0.55
@export var scale_max: float = 1.0
@export var alpha_min: float = 0.35
@export var drag_sensitivity: float = 0.005
@export var friction: float = 0.92 ## Retención de velocidad por frame a 60fps (menor = frena antes).
@export var fling_max_speed: float = 12.0 ## Velocidad angular máxima al soltar (rad/s).
@export var fling_min_speed: float = 0.35 ## Por debajo, el impulso cede al snap (rad/s).
@export var fling_sample_ms: float = 120.0 ## Ventana para medir la velocidad al soltar.
@export var snap_speed: float = 10.0
@export var click_threshold: float = 14.0 ## px máximos para considerar tap (no drag).
@export var idle_timeout: float = 2.0 ## Segundos quieto antes del giro automático.
@export var auto_rotate_speed: float = 0.35 ## Velocidad del giro automático (rad/s, lento).

var global_angle: float = 0.0
var velocity: float = 0.0 ## Velocidad angular actual (rad/s).
var is_dragging: bool = false
var _tiempo_inactivo: float = 0.0 ## Tiempo desde la última interacción.
var _press_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _dragged: bool = false
## Muestras recientes [msec, x] para calcular la velocidad al soltar.
var _drag_samples: Array = []
var _focused_index: int = -1
var _snap_tween: Tween = null

var item_nodes: Array[TextureButton] = []
var current_data: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# Aceptar foco para que ui_left/ui_right/ui_accept funcionen sin botones extra.
	focus_mode = Control.FOCUS_ALL
	# Redibujar al cambiar el tamaño (rotaciones, split-screen, etc.).
	resized.connect(update_carousel_layout)


func setup_carousel(data: Array[Dictionary]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	item_nodes.clear()
	current_data = data.duplicate()
	_focused_index = -1
	velocity = 0.0
	_tiempo_inactivo = 0.0
	global_angle = 0.0

	var count := current_data.size()
	if count == 0:
		return

	for i in range(count):
		var info: Dictionary = current_data[i]
		var btn := TextureButton.new()
		btn.custom_minimum_size = item_size
		btn.size = item_size
		btn.pivot_offset = item_size / 2.0
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var tex: Texture2D = info.get("texture", null) as Texture2D
		if tex != null:
			btn.texture_normal = tex
		var idx := i
		btn.pressed.connect(_on_item_pressed.bind(idx))
		btn.focus_entered.connect(_on_item_focus_entered.bind(idx))
		add_child(btn)
		item_nodes.append(btn)

	# Enfocar el primer ítem para lectores de pantalla / teclado.
	if not item_nodes.is_empty():
		_focused_index = get_centered_index()
		_notify_focus_changed(true)

	update_carousel_layout()


func get_centered_index() -> int:
	if item_nodes.is_empty():
		return -1
	var count := item_nodes.size()
	var step_angle := (PI * 2.0) / float(count)
	var best := 0
	var best_depth := -2.0
	for i in range(count):
		var depth := cos(global_angle + float(i) * step_angle)
		if depth > best_depth:
			best_depth = depth
			best = i
	return best


func focus_next() -> void:
	_rotate_steps(1)


func focus_prev() -> void:
	_rotate_steps(-1)


func select_centered() -> void:
	_registrar_actividad()
	var idx := get_centered_index()
	if idx < 0 or idx >= current_data.size():
		return
	emit_selection(idx)


func emit_selection(idx: int) -> void:
	if idx < 0 or idx >= current_data.size():
		return
	var game_id := str(current_data[idx].get("id", ""))
	if game_id == "":
		return
	Input.vibrate_handheld(25)
	item_selected.emit(game_id)


func _rotate_steps(steps: int) -> void:
	if item_nodes.is_empty():
		return
	_registrar_actividad()
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()
	var count := item_nodes.size()
	var step_angle := (PI * 2.0) / float(count)
	# El ángulo crece hacia la derecha; para avanzar al siguiente ítem hay que
	# retroceder el ángulo global.
	var target: float = round(global_angle / step_angle) * step_angle - float(steps) * step_angle
	velocity = 0.0
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(self, "global_angle", target, 0.35)
	_snap_tween.tween_callback(update_carousel_layout)


func _process(delta: float) -> void:
	if item_nodes.is_empty():
		return
	var count := item_nodes.size()
	var step_angle := (PI * 2.0) / float(count)

	if not is_dragging and (_snap_tween == null or not _snap_tween.is_running()):
		if absf(velocity) > fling_min_speed:
			_tiempo_inactivo = 0.0
			global_angle += velocity * delta
			velocity *= pow(friction, delta * 60.0)
		elif _tiempo_inactivo >= idle_timeout:
			# Vitrina: giro lento continuo sin snap mientras nadie toca.
			global_angle += auto_rotate_speed * delta
		else:
			_tiempo_inactivo += delta
			velocity = 0.0
			var target_angle: float = round(global_angle / step_angle) * step_angle
			global_angle = lerp_angle(global_angle, target_angle, clampf(snap_speed * delta, 0.0, 1.0))
	else:
		# Hay arrastre o animación en curso: la inactividad aún no cuenta.
		_tiempo_inactivo = 0.0

	update_carousel_layout()
	_notify_focus_changed()


func update_carousel_layout() -> void:
	var count := item_nodes.size()
	if count == 0:
		return
	var step_angle := (PI * 2.0) / float(count)
	var center := size / 2.0

	for i in range(count):
		var node := item_nodes[i]
		var angle := global_angle + float(i) * step_angle
		var depth := (cos(angle) + 1.0) / 2.0 # 1 = al frente, 0 = atrás.

		var x := center.x + radius_x * sin(angle) - item_size.x / 2.0
		var y := center.y - item_size.y / 2.0 + arc_height * (1.0 - depth)

		var s := lerpf(scale_min, scale_max, depth)
		# Compensar el escalado para que el centro visual quede en (x, y).
		var offset := (item_size - item_size * s) / 2.0
		node.position = Vector2(x, y) + offset
		node.size = item_size
		node.scale = Vector2(s, s)
		node.modulate.a = lerpf(alpha_min, 1.0, depth)
		node.z_index = int(depth * 100.0)
		# Los ítems traseros no deben robar toques al central.
		node.mouse_filter = Control.MOUSE_FILTER_STOP if depth > 0.55 else Control.MOUSE_FILTER_IGNORE


# --- Entrada táctil / mouse -------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_drag(mb.position)
			else:
				_end_drag(mb.position)
			accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_drag(st.position)
		else:
			_end_drag(st.position)
		accept_event()


func _input(event: InputEvent) -> void:
	# El press se captura aquí (y no solo en _gui_input) porque los
	# TextureButton hijos consumen el evento antes de que llegue al padre.
	# No se consume el evento para no romper el `pressed` (tap) de los botones.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not is_dragging and _press_inside(mb.position):
					_begin_drag(_to_local_pos(mb.position))
			else:
				_end_drag(_to_local_pos(mb.position))
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not is_dragging and _press_inside(st.position):
				_begin_drag(_to_local_pos(st.position))
		else:
			_end_drag(_to_local_pos(st.position))
	elif is_dragging:
		# El motion/release puede llegar fuera del Control: se captura aquí.
		if event is InputEventMouseMotion:
			_drag_to(_to_local_pos((event as InputEventMouseMotion).position))
		elif event is InputEventScreenDrag:
			_drag_to(_to_local_pos((event as InputEventScreenDrag).position))


func _unhandled_key_event(event: InputEvent) -> void:
	if item_nodes.is_empty():
		return
	if event.is_action_pressed("ui_right"):
		focus_next()
		accept_event()
	elif event.is_action_pressed("ui_left"):
		focus_prev()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		select_centered()
		accept_event()


func _begin_drag(pos: Vector2) -> void:
	is_dragging = true
	_registrar_actividad()
	_dragged = false
	velocity = 0.0
	_press_pos = pos
	_last_pos = pos
	_drag_samples = [[Time.get_ticks_msec(), pos.x]]
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()


func _drag_to(pos: Vector2) -> void:
	_registrar_actividad()
	var dx := pos.x - _last_pos.x
	if absf(pos.x - _press_pos.x) > click_threshold:
		_dragged = true
	var angle_delta := dx * drag_sensitivity
	global_angle += angle_delta
	_last_pos = pos
	# Ventana de muestras para medir el impulso al soltar.
	var ahora := Time.get_ticks_msec()
	_drag_samples.append([ahora, pos.x])
	while _drag_samples.size() > 2 and float(ahora) - float(_drag_samples[0][0]) > fling_sample_ms:
		_drag_samples.pop_front()


func _end_drag(pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false
	_registrar_actividad()
	# El impulso se mide con el recorrido de los últimos ~120 ms, no con el
	# último evento (que suele llegar con el dedo ya frenado).
	if _dragged and _drag_samples.size() >= 2:
		var primera: Array = _drag_samples[0]
		var ultima: Array = _drag_samples[_drag_samples.size() - 1]
		var dt_seg := (float(ultima[0]) - float(primera[0])) / 1000.0
		if dt_seg > 0.001:
			var v := (float(ultima[1]) - float(primera[1])) / dt_seg * drag_sensitivity
			velocity = clampf(v, -fling_max_speed, fling_max_speed)
		else:
			velocity = 0.0
	else:
		# Si fue un tap (sin arrastre), el TextureButton central ya emite `pressed`.
		velocity = 0.0
	_drag_samples.clear()
	_last_pos = pos


## Reinicia el conteo de inactividad: cualquier toque, arrastre, tap,
## vuelo a índice o navegación por teclado pospone el giro automático.
func _registrar_actividad() -> void:
	_tiempo_inactivo = 0.0


## Convierte una posición de viewport a coordenadas locales del carrusel.
func _to_local_pos(viewport_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_pos


func _press_inside(viewport_pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_to_local_pos(viewport_pos))


# --- Selección ---------------------------------------------------------------

func _on_item_pressed(idx: int) -> void:
	_registrar_actividad()
	if _dragged:
		return # Fue un drag, no un tap.
	if idx == get_centered_index():
		emit_selection(idx)
	else:
		# Tocar un lateral gira el carrusel hacia ese juego.
		_fly_to_index(idx)


func _on_item_focus_entered(idx: int) -> void:
	# Navegación por teclado / lector de pantalla: llevar el ítem al centro.
	if idx != get_centered_index() and not is_dragging:
		_fly_to_index(idx)


func _fly_to_index(idx: int) -> void:
	if item_nodes.is_empty():
		return
	_registrar_actividad()
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()
	var count := item_nodes.size()
	var step_angle := (PI * 2.0) / float(count)
	var current := get_centered_index()
	var forward := (idx - current + count) % count
	var backward := (current - idx + count) % count
	var target: float
	if forward <= backward:
		target = global_angle - float(forward) * step_angle
	else:
		target = global_angle + float(backward) * step_angle
	velocity = 0.0
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(self, "global_angle", target, 0.35)


## Giro de intro: arranca a alta velocidad y decelera hasta detenerse
## justo al cabo de `duracion` (sincronizado con la subida del logo).
## Da `vueltas` completas, así que termina en el ítem inicial.
## El usuario puede interrumpirlo: arrastrar, tocar o navegar lo cancela.
func spin_intro(duracion: float = 3.0, vueltas: float = 2.0) -> void:
	if item_nodes.is_empty() or duracion <= 0.0:
		return
	_registrar_actividad()
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()
	velocity = 0.0
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(self, "global_angle", global_angle + TAU * vueltas, duracion)


func _notify_focus_changed(force: bool = false) -> void:
	var idx := get_centered_index()
	if idx != _focused_index or force:
		_focused_index = idx
		if idx >= 0 and idx < current_data.size():
			focused_item_changed.emit(idx, str(current_data[idx].get("id", "")))
