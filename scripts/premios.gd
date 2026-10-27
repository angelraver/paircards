extends Control

const CARPETA_PREMIOS = "res://assets/images/prizes/"
const RUTA_RIBBON_AZUL = "res://assets/images/ui/ribbon_tiny_blue.webp"

@onready var grid_premios: GridContainer = $ScrollContainer/ContenidoEstanteria/GridPremios
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var boton_home: TextureButton = $BotonHome

var arrastrando := false

func _ready() -> void:
	scroll_container.gui_input.connect(_on_scroll_container_gui_input)
	refrescar_estanteria()

func _input(event: InputEvent) -> void:

	# ==========================
	# MOUSE
	# ==========================

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				if _puede_empezar_drag(event.position):
					arrastrando = true
			else:
				arrastrando = false

			return

	if event is InputEventMouseMotion and arrastrando:
		_mover_biblioteca(event.relative)
		get_viewport().set_input_as_handled()
		return


	# ==========================
	# TOUCH
	# ==========================

	if event is InputEventScreenTouch:

		if event.pressed:
			if _puede_empezar_drag(event.position):
				arrastrando = true
		else:
			arrastrando = false

		return

	if event is InputEventScreenDrag and arrastrando:
		_mover_biblioteca(event.relative)
		get_viewport().set_input_as_handled()


func _puede_empezar_drag(posicion: Vector2) -> bool:

	# Tiene que estar dentro de la biblioteca
	if not scroll_container.get_global_rect().has_point(posicion):
		return false

	# Pero no encima del botón Home
	if boton_home.get_global_rect().has_point(posicion):
		return false

	return true


func _mover_biblioteca(delta: Vector2) -> void:
	scroll_container.scroll_horizontal -= int(delta.x)
	scroll_container.scroll_vertical -= int(delta.y)
	
func refrescar_estanteria() -> void:
	for child in grid_premios.get_children():
		child.queue_free()

	# Consume directamente la función global unificada de save_manager
	var total_niveles: int = save_manager.obtener_total_niveles_globales()
	var ribbons_azules_obtenidas: int = save_manager.contar_ribbons_azules()
	var cantidad_premios: int = save_manager.LISTA_PREMIOS.size()

	for i in range(cantidad_premios):
		var numero_premio = i + 1
		var nombre_premio = save_manager.LISTA_PREMIOS[i]

		var ribbons_necesarias: int = 1
		if total_niveles > 0 and cantidad_premios > 0:
			ribbons_necesarias = int(ceil(float(numero_premio) * float(total_niveles) / float(cantidad_premios)))

		var desbloqueado: bool = (ribbons_azules_obtenidas >= ribbons_necesarias)

		var slot_premio = crear_slot_premio(nombre_premio, desbloqueado, ribbons_azules_obtenidas, ribbons_necesarias)
		grid_premios.add_child(slot_premio)

func crear_slot_premio(nombre_png: String, desbloqueado: bool, actuales: int, requeridas: int) -> Control:
	var contenedor = Control.new()
	contenedor.custom_minimum_size = Vector2(120, 120)

	var imagen = TextureRect.new()
	var ruta_imagen = CARPETA_PREMIOS + nombre_png + ".png"

	if ResourceLoader.exists(ruta_imagen):
		imagen.texture = load(ruta_imagen)
	
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.set_anchors_preset(Control.PRESET_FULL_RECT)

	contenedor.add_child(imagen)

	if desbloqueado:
		imagen.modulate = Color.WHITE
	else:
		imagen.modulate = Color(0.05, 0.05, 0.05, 0.5)

		var hbox_progreso = HBoxContainer.new()
		hbox_progreso.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox_progreso.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox_progreso.add_theme_constant_override("separation", 6)

		var label_progreso = Label.new()
		label_progreso.text = "%d/%d" % [actuales, requeridas]
		label_progreso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_progreso.modulate = Color(1.0, 0.85, 0.4, 0.9)
		label_progreso.add_theme_font_size_override("font_size", 14)

		var icono_ribbon = TextureRect.new()
		if ResourceLoader.exists(RUTA_RIBBON_AZUL):
			icono_ribbon.texture = load(RUTA_RIBBON_AZUL)
		
		icono_ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono_ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono_ribbon.custom_minimum_size = Vector2(22, 22)

		hbox_progreso.add_child(label_progreso)
		hbox_progreso.add_child(icono_ribbon)
		contenedor.add_child(hbox_progreso)

	return contenedor

func _on_boton_home_pressed() -> void:
	audio_manager.play_ok1()
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		arrastrando = event.pressed
		scroll_container.accept_event()
		return

	if event is InputEventMouseMotion and arrastrando:
		mover_scroll(event.relative)
		scroll_container.accept_event()
		return

	if event is InputEventScreenTouch:
		arrastrando = event.pressed
		scroll_container.accept_event()
		return

	if event is InputEventScreenDrag and arrastrando:
		mover_scroll(event.relative)
		scroll_container.accept_event()

func mover_scroll(delta: Vector2) -> void:
	scroll_container.scroll_horizontal -= int(round(delta.x))
	scroll_container.scroll_vertical -= int(round(delta.y))
