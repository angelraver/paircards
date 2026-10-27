extends Control

@onready var boton_prev: TextureButton = $Frente/BotonPrev
@onready var boton_next: TextureButton = $Frente/BotonNext
@onready var select_level: Label = $Frente/LevelSelection
@onready var fondo: TextureRect = $Fondo # Ajusta la ruta a tu TextureRect de Fondo
@onready var logo: TextureRect = $Logo # Ajusta la ruta a tu TextureRect de Fondo
@onready var frente: TextureRect = $Frente

## Duración de la entrada de Frente y Logo.
const DURACION_INTRO_ENTRADA := 1.0

var pagina_actual: int = 1
var total_niveles: int = 0
const NIVELES_POR_PAGINA: int = 9

var ruta_niveles_json: String = ""
var escena_juego_destino: String = ""

func _ready() -> void:
	# Theme del minijuego: corta main_theme y suena aquí y en partida
	# (el player vive en el autoload, así que continúa sin cortes).
	audio_manager.ensure_game_bgm()
	# 1. Cargar la configuración según el juego actual seleccionado
	var config_juego = game_manager.obtener_config_juego_actual()
	print("juego actual seleccionado: " + save_manager.juego_actual_seleccionado)
	ruta_niveles_json = config_juego.get("ruta_niveles_json", "")
	escena_juego_destino = config_juego.get("escena_juego", "")
	print("ruta_niveles_json: " + ruta_niveles_json)
	print("escena_juego_destino: " + escena_juego_destino)
	# Fondo dinámico según hora del dispositivo (6-17 día, 17-20 tarde, 20-6 noche).
	# Ya no se lee "textura_fondo" de games.json: cada juego queda autocontenido.
	FondoDinamico.aplicar(fondo)
	
	var ruta_logo = config_juego.get("textura_logo", "")
	if logo and ResourceLoader.exists(ruta_logo):
		logo.texture = load(ruta_logo)

	# 2. Obtener total de niveles del minijuego actual
	total_niveles = obtener_total_niveles()

	# 3. Recuperar la página propia de este juego
	var total_paginas: int = maxi(
		1,
		int(ceil(float(total_niveles) / float(NIVELES_POR_PAGINA)))
	)

	pagina_actual = clampi(
		save_manager.obtener_pagina_niveles(),
		1,
		total_paginas
	)

	save_manager.guardar_pagina_niveles(pagina_actual)

	# 4. Conectar señales
	if boton_prev and not boton_prev.pressed.is_connected(_on_boton_prev_pressed):
		boton_prev.pressed.connect(_on_boton_prev_pressed)

	if boton_next and not boton_next.pressed.is_connected(_on_boton_next_pressed):
		boton_next.pressed.connect(_on_boton_next_pressed)

	# 5. Renderizar
	if select_level:
		select_level.text = game_manager.obtener_texto("seleccion_nivel")
	refrescar_pantalla_niveles()

	# 6. Animación de entrada: Logo baja desde arriba, Frente sube desde abajo.
	_animar_intro_entrada()


## Logo entra desde arriba (fuera de pantalla) y Frente desde abajo,
## ambos hasta su posición de la escena en DURACION_INTRO_ENTRADA segundos.
## Sin escalado: solo se anima `position:y`. El pivote se deja en el origen
## para no alterar el render de la escena.
func _animar_intro_entrada() -> void:
	var alto_pantalla := get_viewport_rect().size.y
	var entradas: Array = []
	if logo:
		var h_logo: float = logo.offset_bottom - logo.offset_top
		entradas.append([logo, -h_logo])
	if frente:
		entradas.append([frente, alto_pantalla])
	for item in entradas:
		var control: Control = item[0]
		var destino_y: float = control.position.y
		control.pivot_offset = Vector2.ZERO
		control.position.y = float(item[1])
		var tween: Tween = control.create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "position:y", destino_y, DURACION_INTRO_ENTRADA)

func obtener_total_niveles() -> int:
	if not FileAccess.file_exists(ruta_niveles_json):
		print("ERROR: No se encontró el archivo de niveles en: ", ruta_niveles_json)
		return 0

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var datos_niveles = JSON.parse_string(texto_json)

	if datos_niveles is Dictionary:
		return datos_niveles.keys().size()

	return 0

func refrescar_pantalla_niveles() -> void:
	actualizar_visibilidad_botones()

	var contenedor_slots = $Frente/Slots
	for i in range(1, NIVELES_POR_PAGINA + 1):
		var nombre_nodo = "Slot" + str(i)

		if contenedor_slots.has_node(nombre_nodo):
			var slot = contenedor_slots.get_node(nombre_nodo)
			var numero_nivel_real = (pagina_actual - 1) * NIVELES_POR_PAGINA + i

			if numero_nivel_real <= total_niveles:
				slot.visible = true
				slot.configurar(numero_nivel_real)

				if not slot.nivel_seleccionado.is_connected(_on_nivel_seleccionado):
					slot.nivel_seleccionado.connect(_on_nivel_seleccionado)
			else:
				slot.visible = false

func actualizar_visibilidad_botones() -> void:
	var total_paginas: int = int(ceil(float(total_niveles) / float(NIVELES_POR_PAGINA)))
	if total_paginas < 1:
		total_paginas = 1

	if boton_prev:
		boton_prev.visible = (pagina_actual > 1)

	if boton_next:
		boton_next.visible = (pagina_actual < total_paginas)

func _on_boton_prev_pressed() -> void:
	if pagina_actual > 1:
		audio_manager.play_ok1()
		pagina_actual -= 1
		save_manager.guardar_pagina_niveles(pagina_actual)
		refrescar_pantalla_niveles()

func _on_boton_next_pressed() -> void:
	var total_paginas: int = int(ceil(float(total_niveles) / float(NIVELES_POR_PAGINA)))

	if pagina_actual < total_paginas:
		audio_manager.play_ok1()
		pagina_actual += 1
		save_manager.guardar_pagina_niveles(pagina_actual)
		refrescar_pantalla_niveles()

func _on_nivel_seleccionado(numero_nivel: int) -> void:
	save_manager.nivel_actual_seleccionado = numero_nivel
	audio_manager.play_ok1()
	get_tree().change_scene_to_file(escena_juego_destino)

func _on_boton_home_pressed() -> void:
	audio_manager.play_ok1()
	get_tree().change_scene_to_file("res://scenes/title.tscn")
