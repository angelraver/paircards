extends Node3D

const RADIO_MAX_CAPA: float = 2.1
const CAPACIDAD_BARRA: int = 5
const TIEMPO_COMBO: float = ComboPuntos.VENTANA_COMBO_SEG

const RUTA_NIVELES: String = "res://data/niveles.json"
const RUTA_VALORES: String = "res://data/valores.json"
const RUTA_CARPETA_FICHAS: String = "res://assets/images/astronomia/"
const RUTA_TABLERO_DIA: String = "res://assets/images/tablero.webp"
const RUTA_TABLERO_TARDE: String = "res://assets/images/tablerotarde.webp"
const RUTA_TABLERO_NOCHE: String = "res://assets/images/tableronoche.webp"
const CAPAS_POR_DEFECTO: int = 5

const ESCALA_FICHAS_BARRA: float = 1.3
const TAMANO_SLOT_BARRA := Vector2(96.0, 96.0) * ESCALA_FICHAS_BARRA
const MARGEN_ICONO_BARRA: float = 3.0 * ESCALA_FICHAS_BARRA
const TAMANO_CAMARA_ICONO: float = 0.14

const ALTO_BARRA: float = 200.0

const OSCURIDAD_BASE_CAPAS: Array[float] = [0.10, 0.30, 0.40, 0.50, 0.60]

const ALTURA_PISO: float = -0.04

const ALTURA_BARRA_3D: float = ALTURA_PISO + 0.002

const FICHA_ESCENA: PackedScene = preload("res://assets/models/ficha.glb")
const SHADER_CARA: Shader = preload("res://shaders/ficha_cara.gdshader")

const DIAMETRO_FICHA: float = 0.132
const GROSOR_FICHA: float = 0.022
const SEPARACION_CAPAS: float = 0.026

const SEPARACION_FICHAS: float = DIAMETRO_FICHA

const SQRT3: float = 1.7320508075688772

const DESPLAZAMIENTO_INTERCALADO := Vector2(0.5, 0.28867513459481287)

const DURACION_VUELO: float = 1.1

const ALTURA_SALTO_SELECCION: float = DIAMETRO_FICHA * 1.2
const DURACION_SALTO: float = DURACION_VUELO * 0.18

const CENTRO_TABLERO := Vector3(0.0, 0.0, 0.16)

const CAPA_COLISION_FICHAS: int = 2

const ALTURA_CAIDA_INICIAL: float = 4.0
const DURACION_CAIDA: float = 0.7
const ESCALON_CAIDA_POR_CAPA: float = 0.12
const ESPACIO_ENTRE_FICHAS: float = 0.05

var _fichas_config: Dictionary = {}

# ============================================================================
#  NODOS DE LA ESCENA
# ============================================================================
@onready var contenedor_fichas: Node3D = $BoardElements
@onready var camara: Camera3D = $Camera3D
@onready var piso_tablero: CSGBox3D = $Piso

@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var main_audio: MainAudio = $MainAudio as MainAudio
@onready var boton_pausa: TextureButton = $UI/BotonPausa
@onready var panel_pausa: PanelPausa = $UI/PanelPausa as PanelPausa

# ============================================================================
#  ESTADO DEL JUEGO
# ============================================================================
var nivel_actual: int = 1
var _puntaje_nivel: int = 0
var ctrl_resultados: ControladorResultados
var _geometria: TableroGeometria
var _visibilidad: TableroVisibilidad
var _efectos: EfectosPartida
var _titulo: TituloPartida

var _niveles_config: Dictionary = {}
var _valores_config: Dictionary = {}
var _capas_nivel: int = CAPAS_POR_DEFECTO
var _slots_nivel: int = CAPACIDAD_BARRA
var _tipos_nivel: Array[int] = []
var _fichas_n_nivel: int = 0
var _score_nivel: int = 0

var _fichas_tablero: Array[FichaTablero] = []
var _texturas: Array[Texture2D] = []

var _radio_ficha: float = 1.0
var _escala_ficha: Vector3 = Vector3.ONE
var _offset_ficha: Vector3 = Vector3.ZERO
var _indice_cara_superior: int = 0

var _barra_tipos: Array[int] = []
var _barra_conteo: Array[int] = []
var _barra_icono_oculto: Array[bool] = []
var _combo_activo: bool = false
var _combo_tipo: int = 0
var _combo_slot: int = -1
var _combo_contador: int = 0
var _timer_combo: Timer = null
var _fichas_en_vuelo: Array[FichaTablero] = []
var _slots_en_vuelo: Array[int] = []
var _juego_terminado: bool = false
var _animando_entrada: bool = false
var _pendientes_entrada: int = 0

var _fichas_por_capa: Array[int] = []
var _total_fichas: int = 0
var _total_pares: int = 0

var _barra_ui: Control = null
var _barra_viewport: SubViewport = null
var _barra_sprite: Sprite3D = null
var _barra_slots_box: HBoxContainer = null
var _slots: Array[Panel] = []
var _slots_texturas: Array[TextureRect] = []
var _slots_viewports: Array[SubViewport] = []
var _slots_fichas: Array[Node3D] = []
var _slots_materiales: Array[ShaderMaterial] = []

# ============================================================================
#  CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	randomize()
	if OS.is_debug_build():
		ComboPuntos.verificar_reglas()

	FondoDinamico.aplicar_material(
		piso_tablero.material,
		RUTA_TABLERO_DIA,
		RUTA_TABLERO_TARDE,
		RUTA_TABLERO_NOCHE
	)

	nivel_actual = save_manager.nivel_actual_seleccionado
	_cargar_configuracion()

	_geometria = TableroGeometria.new()
	_visibilidad = TableroVisibilidad.new()
	_visibilidad.configurar(DIAMETRO_FICHA, OSCURIDAD_BASE_CAPAS)

	_preparar_ficha()
	_configurar_nivel(nivel_actual)
	_cargar_texturas()
	_crear_barra_ui()

	_efectos = EfectosPartida.new()
	add_child(_efectos)
	var ui_capa := $UI as CanvasLayer
	_efectos.configurar(ui_capa, camara, _slots)

	_titulo = TituloPartida.new()
	_titulo.configurar(ui_level_title)
	_crear_timer_combo()

	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	ctrl_resultados.configurar(
		panel_resultados,
		[ui_level_number, ui_puntaje, boton_pausa, _barra_ui],
		ui_level_number,
		reiniciar_nivel
	)

	if boton_pausa and not boton_pausa.is_connected("pressed", _on_boton_pausa_pressed):
		boton_pausa.pressed.connect(_on_boton_pausa_pressed)

	if not game_manager.is_connected("idioma_cambiado", _on_idioma_cambiado):
		game_manager.idioma_cambiado.connect(_on_idioma_cambiado)

	_cargar_nivel(nivel_actual)

# ============================================================================
#  CARGA DE RECURSOS Y CONFIGURACIÓN
# ============================================================================
func _cargar_json(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		push_error("No se encontró el archivo de configuración: %s" % ruta)
		return {}
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir el archivo de configuración: %s" % ruta)
		return {}
	var texto := archivo.get_as_text()
	var datos = JSON.parse_string(texto)
	if datos is Dictionary:
		return datos
	push_error("El archivo de configuración no es un objeto JSON válido: %s" % ruta)
	return {}

func _cargar_configuracion() -> void:
	_niveles_config = _cargar_json(RUTA_NIVELES)
	_valores_config = _cargar_json(RUTA_VALORES)

func _configurar_nivel(n: int) -> void:
	_fichas_config.clear()
	_tipos_nivel.clear()
	_capas_nivel = CAPAS_POR_DEFECTO
	_slots_nivel = CAPACIDAD_BARRA
	_fichas_n_nivel = 0
	_score_nivel = 0

	var mapa_fichas: Dictionary = _valores_config.get("fichas", {})
	var nivel_cfg: Variant = _niveles_config.get(str(n), _niveles_config.get(n, {}))
	if not (nivel_cfg is Dictionary):
		nivel_cfg = {}

	_capas_nivel = maxi(int(nivel_cfg.get("capas", CAPAS_POR_DEFECTO)), 1)
	_slots_nivel = clampi(int(nivel_cfg.get("slots", CAPACIDAD_BARRA)), 1, CAPACIDAD_BARRA)
	_fichas_n_nivel = maxi(int(nivel_cfg.get("fichas_n", 0)), 0)
	_score_nivel = maxi(int(nivel_cfg.get("score", 0)), 0)

	_geometria.configurar_nivel(_capas_nivel, nivel_cfg.get("patron", "circulos"))

	var tipos_cfg: Array = nivel_cfg.get("fichas_t", [])
	for clave in tipos_cfg:
		var tipo_id := str(clave)
		if not mapa_fichas.has(tipo_id):
			push_error("Tipo de ficha desconocido en nivel %d: %s" % [n, tipo_id])
			continue
		var nombre: String = str(mapa_fichas[tipo_id])
		var indice := _tipos_nivel.size() + 1
		_tipos_nivel.append(indice)
		_fichas_config[indice] = nombre

	if _tipos_nivel.is_empty():
		var claves: Array = mapa_fichas.keys()
		claves.sort()
		for clave in claves:
			var nombre: String = str(mapa_fichas[clave])
			var indice := _tipos_nivel.size() + 1
			_tipos_nivel.append(indice)
			_fichas_config[indice] = nombre

func _cargar_texturas() -> void:
	_texturas.clear()
	for indice in _tipos_nivel:
		var nombre: String = str(_fichas_config.get(indice, ""))
		var ruta := RUTA_CARPETA_FICHAS + nombre + ".png"
		var textura := load(ruta) as Texture2D
		if textura == null:
			push_error("No se pudo cargar la textura de ficha: %s" % ruta)
		_texturas.append(textura)

func _textura_para_tipo(tipo: int) -> Texture2D:
	var indice := tipo - 1
	if indice < 0 or indice >= _texturas.size():
		return null
	return _texturas[indice]

func _preparar_ficha() -> void:
	var temporal := FICHA_ESCENA.instantiate()
	var malla := _buscar_mesh_instance(temporal)
	if malla == null or malla.mesh == null:
		push_error("No se pudo obtener la malla de res://assets/models/ficha.glb")
		temporal.free()
		return

	var aabb := malla.mesh.get_aabb()
	_radio_ficha = maxf(aabb.size.x, aabb.size.z) * 0.5

	var escala_xz := DIAMETRO_FICHA / (2.0 * _radio_ficha)
	var escala_y := GROSOR_FICHA / maxf(aabb.size.y, 0.0001)
	_escala_ficha = Vector3(escala_xz, escala_y, escala_xz)

	_offset_ficha = Vector3(
		-aabb.get_center().x * escala_xz,
		-aabb.end.y * escala_y,
		-aabb.get_center().z * escala_xz
	)

	_indice_cara_superior = _indice_superficie_superior(malla.mesh)
	temporal.free()

func _buscar_mesh_instance(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo as MeshInstance3D
	for hijo in nodo.get_children():
		var encontrada := _buscar_mesh_instance(hijo)
		if encontrada != null:
			return encontrada
	return null

func _indice_superficie_superior(malla: Mesh) -> int:
	for i in range(malla.get_surface_count()):
		var material := malla.surface_get_material(i)
		if material != null and material.resource_name.to_lower().contains("superior"):
			return i

	var mejor := 0
	var mejor_score := -1.0
	for i in range(malla.get_surface_count()):
		var arrays := malla.surface_get_arrays(i)
		var normales = arrays[Mesh.ARRAY_NORMAL]
		if normales == null or normales.is_empty():
			continue
		var arriba := 0
		for normal in normales:
			if normal.y > 0.9:
				arriba += 1
		var score := float(arriba) / float(normales.size())
		if score > mejor_score:
			mejor_score = score
			mejor = i
	return mejor

func _crear_material_cara(textura: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER_CARA
	material.set_shader_parameter("albedo_textura", textura)
	material.set_shader_parameter("radio_cara", _radio_ficha)
	material.set_shader_parameter("brillo", 1.0)
	return material

func _configurar_visual_ficha(ficha: Node3D, textura: Texture2D) -> ShaderMaterial:
	var malla := _buscar_mesh_instance(ficha)
	if malla == null or malla.mesh == null:
		return null

	malla.scale = _escala_ficha
	malla.position = _offset_ficha
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := _crear_material_cara(textura)
	if _indice_cara_superior < malla.mesh.get_surface_count():
		malla.set_surface_override_material(_indice_cara_superior, material)
	return material

func _crear_entorno_ficha() -> Environment:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_CLEAR_COLOR
	entorno.background_color = Color(0.0, 0.0, 0.0, 0.0)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.627451, 0.627451, 0.627451)
	entorno.ambient_light_energy = 0.5
	return entorno

# ============================================================================
#  GENERACIÓN PROCEDURAL DEL NIVEL
# ============================================================================
func _cargar_nivel(n: int) -> void:
	_juego_terminado = false
	nivel_actual = n
	_puntaje_nivel = 0

	_configurar_nivel(n)
	if ui_puntaje:
		ui_puntaje.establecer_puntaje(0)
		ui_puntaje.establecer_maximo(_score_nivel)
		ui_puntaje.establecer_hi_score(save_manager.obtener_puntaje_nivel(n))
	_cargar_texturas()
	if _barra_ui == null or _slots.size() != _slots_nivel:
		_crear_barra_ui()
		if _efectos != null:
			_efectos.actualizar_slots(_slots)
	_preparar_reparto()

	_barra_tipos.clear()
	_barra_conteo.clear()
	_barra_icono_oculto.clear()
	for _i in range(_slots_nivel):
		_barra_tipos.append(0)
		_barra_conteo.append(0)
		_barra_icono_oculto.append(false)
	_combo_activo = false
	_combo_tipo = 0
	_combo_slot = -1
	_combo_contador = 0
	_fichas_en_vuelo.clear()
	_slots_en_vuelo.clear()
	if _timer_combo:
		_timer_combo.stop()
	_actualizar_barra_ui()
	_limpiar_tablero()
	_efectos.limpiar()

	_titulo.actualizar_nivel(n)
	if ctrl_resultados:
		ctrl_resultados.reset()
	if ui_level_number:
		ui_level_number.establecer_nivel(n)

	_generar_fichas()
	_animar_entrada_fichas()

func _preparar_reparto() -> void:
	_fichas_por_capa.clear()
	var total := 0

	for capa in range(1, _capas_nivel + 1):
		var capacidad := _geometria.capacidad_capa(capa)
		_fichas_por_capa.append(capacidad)
		total += capacidad

	if total % 2 != 0:
		_fichas_por_capa[_capas_nivel - 1] -= 1
		total -= 1

	var objetivo := total
	if _fichas_n_nivel > 0:
		objetivo = mini(_fichas_n_nivel, total)
	if objetivo % 2 != 0:
		objetivo -= 1
	objetivo = maxi(objetivo, 0)

	var sobrantes := total - objetivo
	for i in range(_fichas_por_capa.size() - 1, -1, -1):
		if sobrantes <= 0:
			break
		var quitar := mini(sobrantes, _fichas_por_capa[i])
		_fichas_por_capa[i] -= quitar
		sobrantes -= quitar

	_total_fichas = objetivo
	_total_pares = _total_fichas / 2
	print("Reparto nivel ", nivel_actual, ": capas=", _capas_nivel, " fichas_n=", _fichas_n_nivel, " por_capa=", _fichas_por_capa, " total=", _total_fichas, " pares=", _total_pares)

func _generar_fichas() -> void:
	if _tipos_nivel.is_empty():
		push_error("El nivel %d no tiene tipos de ficha configurados." % nivel_actual)
		return

	var tipos: Array[int] = []

	for _i in range(_total_pares):
		var tipo: int = _tipos_nivel[randi() % _tipos_nivel.size()]
		tipos.append(tipo)
		tipos.append(tipo)

	tipos.shuffle()

	var indice_tipo: int = 0

	for capa in range(1, _capas_nivel + 1):
		var celdas := _geometria.generar_celdas(capa)

		celdas.shuffle()

		var cantidad: int = _fichas_por_capa[capa - 1]
		cantidad = mini(cantidad, celdas.size())

		for i in range(cantidad):
			if indice_tipo >= tipos.size():
				break
			_crear_ficha(tipos[indice_tipo], capa, celdas[i])
			indice_tipo += 1

func _crear_ficha(tipo: int, capa: int, celda: Vector2i) -> void:
	var textura := _textura_para_tipo(tipo)
	if textura == null:
		return

	var nodo_ficha := FICHA_ESCENA.instantiate() as Node3D
	var material_cara: ShaderMaterial = null
	if nodo_ficha != null:
		material_cara = _configurar_visual_ficha(nodo_ficha, textura)
	if nodo_ficha == null or material_cara == null:
		push_error("No se pudo instanciar la malla de ficha.glb")
		if nodo_ficha:
			nodo_ficha.free()
		return

	var ficha := FichaTablero.new()
	ficha.name = "Ficha_L%d_Q%d_R%d" % [capa, celda.x, celda.y]
	ficha.construir(
		tipo,
		capa,
		celda,
		textura,
		nodo_ficha,
		material_cara,
		DIAMETRO_FICHA,
		GROSOR_FICHA,
		CAPA_COLISION_FICHAS
	)

	contenedor_fichas.add_child(ficha)
	var pos_final := _geometria.posicion_mundo(celda, capa)
	ficha.position = Vector3(pos_final.x, ALTURA_CAIDA_INICIAL, pos_final.z)
	_fichas_tablero.append(ficha)

func _animar_entrada_fichas() -> void:
	_animando_entrada = true
	_pendientes_entrada = 0

	var todas_fichas: Array = _fichas_tablero.duplicate()
	todas_fichas.sort_custom(Callable(self, "_ordenar_entrada_ficha"))
	randomize()

	var delay_actual: float = 0.0
	for ficha in todas_fichas:
		var pos_final := _geometria.posicion_mundo(ficha.celda, ficha.capa)
		var tween: Tween = ficha.create_tween()
		tween.tween_interval(delay_actual)
		tween.tween_property(ficha, "position:y", pos_final.y, DURACION_CAIDA) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(_on_entrada_ficha_terminada)
		_pendientes_entrada += 1
		delay_actual += ESPACIO_ENTRE_FICHAS

func _ordenar_entrada_ficha(a, b) -> int:
	if a.capa != b.capa:
		return b.capa - a.capa
	return 0

func _on_entrada_ficha_terminada() -> void:
	_pendientes_entrada -= 1
	if main_audio != null:
		main_audio.play_drop()
	if _pendientes_entrada <= 0:
		_animando_entrada = false
		_visibilidad.actualizar(_fichas_tablero)

# ============================================================================
#  INPUT Y SELECCIÓN
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _juego_terminado or get_tree().paused:
		return
	if _animando_entrada:
		return
	if panel_resultados and panel_resultados.visible:
		return	

	if event is InputEventScreenTouch:
		if event.pressed:
			_intentar_seleccionar(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed \
		and not DisplayServer.is_touchscreen_available():
			_intentar_seleccionar(event.position)
			get_viewport().set_input_as_handled()

func _intentar_seleccionar(pos_2d: Vector2) -> void:
	if _juego_terminado or _animando_entrada:
		return

	var ficha := _ficha_bajo_punto(pos_2d)
	if ficha == null:
		return

	if not ficha.libre:
		return

	_seleccionar_ficha(ficha)

func _ficha_bajo_punto(pos_2d: Vector2) -> FichaTablero:
	if camara == null:
		return null

	var origen := camara.project_ray_origin(pos_2d)
	var direccion := camara.project_ray_normal(pos_2d)
	var destino := origen + direccion * 10.0

	var consulta := PhysicsRayQueryParameters3D.create(
		origen,
		destino,
		CAPA_COLISION_FICHAS
	)
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		return null

	var colisionador = resultado.get("collider")
	if colisionador == null or not colisionador.has_meta("ficha"):
		return null

	var ficha: FichaTablero = colisionador.get_meta("ficha")
	return ficha

func _seleccionar_ficha(ficha: FichaTablero) -> void:
	if _juego_terminado or not ficha.libre:
		return

	var tipo := ficha.tipo
	var es_ultima_ficha: bool = _fichas_tablero.size() == 1

	var slot_match := _buscar_slot_por_tipo(tipo)

	if slot_match != -1:
		if _combo_activo and _combo_slot == slot_match:
			_combo_contador += 1
		else:
			if _combo_activo:
				_romper_combo()
			_combo_activo = true
			_combo_tipo = tipo
			_combo_slot = slot_match
			_combo_contador = _barra_conteo[slot_match] + 1
		_barra_conteo[_combo_slot] = _combo_contador
	else:
		if _combo_activo:
			_romper_combo()
		var slot := _primer_slot_libre()
		if slot == -1:
			_finalizar_partida(false)
			return
		_combo_activo = true
		_combo_tipo = tipo
		_combo_slot = slot
		_combo_contador = 1
		_barra_tipos[slot] = tipo
		_barra_conteo[slot] = 1
		_barra_icono_oculto[slot] = true

	_barra_tipos[_combo_slot] = tipo
	_slots_en_vuelo.append(_combo_slot)

	var puntos_ganados := 0
	if _combo_contador >= 2:
		puntos_ganados = _combo_contador - 1

	_animar_ficha_a_barra(ficha, _combo_slot, puntos_ganados, es_ultima_ficha)

	if main_audio:
		main_audio.play_select()

	_fichas_tablero.erase(ficha)
	ficha.libre = false
	if ficha.cuerpo:
		ficha.cuerpo.collision_layer = 0
	_fichas_en_vuelo.append(ficha)

	_visibilidad.actualizar(_fichas_tablero)

func _crear_timer_combo() -> void:
	_timer_combo = Timer.new()
	_timer_combo.name = "TimerCombo"
	_timer_combo.one_shot = true
	_timer_combo.wait_time = TIEMPO_COMBO
	_timer_combo.timeout.connect(_on_timer_combo_timeout)
	add_child(_timer_combo)

func _romper_combo() -> void:
	if not _combo_activo:
		return
	if _timer_combo:
		_timer_combo.stop()

	var hay_coincidencias := _combo_contador >= 2

	if hay_coincidencias:
		for ficha in _fichas_en_vuelo:
			if is_instance_valid(ficha):
				ficha.queue_free()
		_fichas_en_vuelo.clear()
		while _slots_en_vuelo.has(_combo_slot):
			_slots_en_vuelo.erase(_combo_slot)
		var resultado_combo: Dictionary = ComboPuntos.calcular_puntos_combo(_combo_contador)
		var combo_acumulado: int = int(resultado_combo["puntos"])
		_puntaje_nivel += combo_acumulado
		if ui_puntaje:
			ui_puntaje.establecer_puntaje(_puntaje_nivel)
		_efectos.mostrar_puntos_flotantes_en_slot(_combo_slot, combo_acumulado, false, str(resultado_combo["etiqueta"]))
		if _combo_slot >= 0 and _combo_slot < _slots.size() and camara != null:
			var slot := _slots[_combo_slot]
			var rect_slot := slot.get_global_rect()
			var pantalla := get_viewport().get_visible_rect().size
			var centro_slot := Vector2(
				rect_slot.get_center().x,
				pantalla.y - ALTO_BARRA + rect_slot.get_center().y
			)
			var plano := Plane(Vector3.UP, ALTURA_BARRA_3D)
			var interseccion: Variant = plano.intersects_ray(
				camara.project_ray_origin(centro_slot),
				camara.project_ray_normal(centro_slot)
			)
			if interseccion != null:
				_efectos.disparar_smoke_puff(interseccion)
		if _combo_slot >= 0 and _combo_slot < _barra_tipos.size():
			_barra_tipos[_combo_slot] = 0
			_barra_conteo[_combo_slot] = 0
			_barra_icono_oculto[_combo_slot] = false
	else:
		_fichas_en_vuelo.clear()

	_actualizar_barra_ui()
	_combo_activo = false
	_combo_tipo = 0
	_combo_slot = -1
	_combo_contador = 0

	if _fichas_tablero.is_empty():
		_finalizar_partida(true)

func _on_timer_combo_timeout() -> void:
	if _combo_activo and _slots_en_vuelo.has(_combo_slot):
		return
	_romper_combo()

func _barra_esta_vacia() -> bool:
	for t in _barra_tipos:
		if t != 0:
			return false
	return true

func _primer_slot_libre() -> int:
	for i in range(_barra_tipos.size()):
		if _barra_tipos[i] == 0:
			return i
	return -1

func _buscar_slot_por_tipo(tipo: int) -> int:
	if tipo == 0:
		return -1
	for i in range(_barra_tipos.size()):
		if _barra_tipos[i] == tipo:
			return i
	return -1

func _iniciar_timer_combo() -> void:
	if _timer_combo:
		_timer_combo.stop()
		_timer_combo.start()

# ============================================================================
#  BARRA INFERIOR ("SCRABBLE BAR")
# ============================================================================
func _crear_barra_ui() -> void:
	var entorno_ficha := _crear_entorno_ficha()
	var textura_inicial: Texture2D = null
	if not _texturas.is_empty():
		textura_inicial = _texturas[0]

	if _barra_ui == null or not is_instance_valid(_barra_ui):
		_barra_ui = Control.new()
		_barra_ui.name = "BarraRecoleccion"
		_barra_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barra_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var fondo := ColorRect.new()
		fondo.name = "Fondo"
		fondo.color = Color(0.02, 0.02, 0.04, 0.62)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barra_ui.add_child(fondo)

		var linea := ColorRect.new()
		linea.name = "Linea"
		linea.color = Color(0.95, 0.78, 0.25, 0.9)
		linea.anchor_left = 0.0
		linea.anchor_top = 0.0
		linea.anchor_right = 1.0
		linea.anchor_bottom = 0.0
		linea.offset_bottom = 3.0
		linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barra_ui.add_child(linea)

		_barra_slots_box = HBoxContainer.new()
		_barra_slots_box.name = "Slots"
		_barra_slots_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_barra_slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_barra_slots_box.add_theme_constant_override("separation", 12)
		_barra_slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barra_ui.add_child(_barra_slots_box)

		_barra_viewport = SubViewport.new()
		_barra_viewport.name = "BarraViewport"
		_barra_viewport.transparent_bg = true
		_barra_viewport.disable_3d = true
		_barra_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_barra_viewport)
		_barra_viewport.add_child(_barra_ui)

		_barra_sprite = Sprite3D.new()
		_barra_sprite.name = "Barra3D"
		_barra_sprite.texture = _barra_viewport.get_texture()
		_barra_sprite.shaded = false
		_barra_sprite.double_sided = true
		_barra_sprite.flip_h = true
		_barra_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_barra_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_barra_sprite)
		_actualizar_barra_3d()
		if not get_viewport().size_changed.is_connected(_actualizar_barra_3d):
			get_viewport().size_changed.connect(_actualizar_barra_3d)
	else:
		_barra_slots_box = _barra_ui.get_node_or_null("Slots") as HBoxContainer

	for hijo in _barra_slots_box.get_children():
		_barra_slots_box.remove_child(hijo)
		hijo.queue_free()
	_slots.clear()
	_slots_texturas.clear()
	_slots_viewports.clear()
	_slots_fichas.clear()
	_slots_materiales.clear()

	for _i in range(_slots_nivel):
		var slot := Panel.new()
		slot.custom_minimum_size = TAMANO_SLOT_BARRA
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.08, 0.08, 0.12, 0.88)
		estilo.border_color = Color(0.95, 0.78, 0.25, 0.8)
		estilo.set_border_width_all(2)
		estilo.set_corner_radius_all(int(TAMANO_SLOT_BARRA.x * 0.5))
		slot.add_theme_stylebox_override("panel", estilo)

		var icono := TextureRect.new()
		icono.name = "Ficha"
		icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icono.offset_left = MARGEN_ICONO_BARRA
		icono.offset_top = MARGEN_ICONO_BARRA
		icono.offset_right = -MARGEN_ICONO_BARRA
		icono.offset_bottom = -MARGEN_ICONO_BARRA
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icono.visible = false
		slot.add_child(icono)

		var viewport := SubViewport.new()
		viewport.name = "VistaFicha"
		viewport.size = Vector2i(192, 192)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.msaa_3d = Viewport.MSAA_4X
		slot.add_child(viewport)

		var camara_ficha := Camera3D.new()
		camara_ficha.name = "Camara"
		camara_ficha.projection = Camera3D.PROJECTION_ORTHOGONAL
		camara_ficha.size = TAMANO_CAMARA_ICONO
		camara_ficha.near = 0.01
		camara_ficha.far = 10.0
		camara_ficha.environment = entorno_ficha
		var base := Basis.IDENTITY
		if camara:
			base = camara.global_transform.basis.orthonormalized()
		var centro := Vector3(0.0, -GROSOR_FICHA * 0.5, 0.0)
		camara_ficha.transform = Transform3D(base, centro + base.z * 0.3)
		camara_ficha.current = true
		viewport.add_child(camara_ficha)

		for nombre_luz in ["DirectionalLight3D", "SunLight"]:
			var fuente := get_node_or_null(nombre_luz) as DirectionalLight3D
			if fuente:
				var luz := DirectionalLight3D.new()
				luz.name = "Luz_" + nombre_luz
				luz.transform = fuente.transform
				luz.light_color = fuente.light_color
				luz.light_energy = fuente.light_energy
				luz.shadow_enabled = false
				viewport.add_child(luz)

		var ficha: Node3D = FICHA_ESCENA.instantiate() as Node3D
		var material_ficha: ShaderMaterial = null
		if ficha != null:
			material_ficha = _configurar_visual_ficha(ficha, textura_inicial)
		if ficha != null and material_ficha != null:
			ficha.visible = false
			viewport.add_child(ficha)
		elif ficha != null:
			ficha.free()
			ficha = null

		_barra_slots_box.add_child(slot)
		_slots.append(slot)
		_slots_texturas.append(icono)
		_slots_viewports.append(viewport)
		_slots_fichas.append(ficha)
		_slots_materiales.append(material_ficha)

	_actualizar_barra_ui()

func _actualizar_barra_3d() -> void:
	if _barra_viewport == null or _barra_sprite == null or camara == null:
		return

	var pantalla := get_viewport().get_visible_rect().size
	_barra_viewport.size = Vector2i(int(pantalla.x), int(ALTO_BARRA))

	var plano := Plane(Vector3.UP, ALTURA_BARRA_3D)
	var esquina_sup := Vector2(0.0, pantalla.y - ALTO_BARRA)
	var esquina_inf := Vector2(pantalla.x, pantalla.y)
	var sup: Variant = plano.intersects_ray(
		camara.project_ray_origin(esquina_sup),
		camara.project_ray_normal(esquina_sup)
	)
	var inf: Variant = plano.intersects_ray(
		camara.project_ray_origin(esquina_inf),
		camara.project_ray_normal(esquina_inf)
	)
	if sup == null or inf == null:
		return

	var sup_v: Vector3 = sup
	var inf_v: Vector3 = inf
	var centro := (sup_v + inf_v) * 0.5
	var tam := Vector2(absf(sup_v.x - inf_v.x), absf(sup_v.z - inf_v.z))
	var tam_tex := Vector2(_barra_viewport.size)

	_barra_sprite.position = centro
	_barra_sprite.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_barra_sprite.pixel_size = 1.0
	if tam_tex.x > 0.0 and tam_tex.y > 0.0:
		_barra_sprite.scale = Vector3(tam.x / tam_tex.x, tam.y / tam_tex.y, 1.0)

func _actualizar_barra_ui() -> void:
	for i in range(_slots.size()):
		var icono := _slots_texturas[i]
		var viewport := _slots_viewports[i]
		var ficha := _slots_fichas[i]
		var material := _slots_materiales[i]

		var tipo := 0
		if i < _barra_tipos.size():
			tipo = _barra_tipos[i]
		var textura := _textura_para_tipo(tipo)

		if tipo != 0 and textura != null and ficha != null and material != null and not _barra_icono_oculto[i]:
			icono.texture = viewport.get_texture()
			icono.visible = true
			ficha.visible = true
			material.set_shader_parameter("albedo_textura", textura)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			icono.visible = false
			if ficha:
				ficha.visible = false
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _agregar_a_barra(tipo: int) -> void:
	if _juego_terminado:
		return

	if _combo_slot >= 0 and _combo_slot < _barra_tipos.size():
		_barra_tipos[_combo_slot] = tipo
	_actualizar_barra_ui()

	if _fichas_tablero.is_empty():
		_finalizar_partida(true)

func _animar_ficha_a_barra(ficha: FichaTablero, indice_slot: int, puntos_ganados: int = 0, es_ultima_ficha: bool = false) -> void:
	if _slots.is_empty() or camara == null:
		ficha.queue_free()
		return

	var slot := _slots[clampi(indice_slot, 0, _slots.size() - 1)]
	var rect_slot := slot.get_global_rect()
	var pantalla := get_viewport().get_visible_rect().size
	var centro_slot := Vector2(
		rect_slot.get_center().x,
		pantalla.y - ALTO_BARRA + rect_slot.get_center().y
	)

	var plano := Plane(Vector3.UP, ficha.global_position.y)
	var interseccion: Variant = plano.intersects_ray(
		camara.project_ray_origin(centro_slot),
		camara.project_ray_normal(centro_slot)
	)
	if interseccion == null:
		ficha.queue_free()
		return

	var destino: Vector3 = interseccion

	var radio := DIAMETRO_FICHA * 0.5
	var ancho_token := camara.unproject_position(destino + Vector3(radio, 0.0, 0.0)) \
		.distance_to(camara.unproject_position(destino - Vector3(radio, 0.0, 0.0)))
	var ancho_icono := (slot.size.x - MARGEN_ICONO_BARRA * 2.0) \
		* (DIAMETRO_FICHA / TAMANO_CAMARA_ICONO)
	var escala_final := 1.0
	if ancho_token > 0.001:
		escala_final = clampf(ancho_icono / ancho_token, 0.3, 1.0)

	var origen: Vector3 = ficha.global_position
	var distancia := origen.distance_to(destino)
	var altura_arco := clampf(distancia * 0.25, 0.05, 0.18)

	var origen_vuelo := origen + Vector3(0.0, ALTURA_SALTO_SELECCION, 0.0)
	var mover := func(t: float) -> void:
		var pos := origen_vuelo.lerp(destino, t)
		pos.y += sin(t * PI) * altura_arco
		ficha.global_position = pos

	var tween := ficha.create_tween()
	tween.tween_property(ficha, "global_position:y", origen_vuelo.y, DURACION_SALTO) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tween.chain().tween_method(mover, 0.0, 1.0, DURACION_VUELO) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(ficha, "rotation:x", -TAU * 2.0, DURACION_VUELO) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(ficha, "scale", Vector3.ONE * escala_final, DURACION_VUELO) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(ficha):
			ficha.queue_free()
		if main_audio:
			main_audio.play_select()
		var idx := _slots_en_vuelo.find(indice_slot)
		if idx != -1:
			_slots_en_vuelo.remove_at(idx)
		if indice_slot >= 0 and indice_slot < _barra_icono_oculto.size():
			_barra_icono_oculto[indice_slot] = false
		_actualizar_barra_ui()
		if puntos_ganados > 0:
			_efectos.mostrar_puntos_flotantes_en_slot(indice_slot, puntos_ganados)
		if es_ultima_ficha and not _juego_terminado:
			if _combo_activo and _combo_slot == indice_slot and _combo_contador >= 2:
				_romper_combo()
			else:
				_finalizar_partida(true)
		elif _combo_activo and _combo_slot == indice_slot:
			_iniciar_timer_combo()
	)

# ============================================================================
#  LIMPIEZA Y FIN DE PARTIDA
# ============================================================================
func _limpiar_tablero() -> void:
	_fichas_tablero.clear()
	if contenedor_fichas == null:
		return
	for hijo in contenedor_fichas.get_children():
		contenedor_fichas.remove_child(hijo)
		hijo.queue_free()

func _on_idioma_cambiado(_nuevo_idioma: String) -> void:
	if not _juego_terminado:
		_titulo.actualizar_nivel(nivel_actual)

func _finalizar_partida(victoria: bool) -> void:
	if _juego_terminado:
		return
	_juego_terminado = true

	if victoria:
		if audio_manager:
			audio_manager.play_welldone()
		_titulo.mostrar_mensaje("¡Nivel completado!")
	else:
		if audio_manager:
			audio_manager.play_fail()
		_titulo.mostrar_mensaje("¡Sin espacio!")

	await get_tree().create_timer(1.2, false).timeout
	if not is_inside_tree():
		return

	_titulo.ocultar()
	mostrar_panel_resultados(victoria)
	if ui_puntaje:
		ui_puntaje.establecer_hi_score(save_manager.obtener_puntaje_nivel(nivel_actual))

func mostrar_panel_resultados(nivel_superado: bool = false) -> void:
	if ctrl_resultados:
		ctrl_resultados.mostrar(nivel_actual, _puntaje_nivel, nivel_superado, _score_nivel)

func reiniciar_nivel() -> void:
	_cargar_nivel(nivel_actual)

# ============================================================================
#  PAUSA
# ============================================================================
func _on_boton_pausa_pressed() -> void:
	if _juego_terminado:
		return
	if panel_resultados and panel_resultados.visible:
		return
	if panel_pausa == null:
		return
	if panel_pausa.visible:
		return
	audio_manager.play_ok1()
	panel_pausa.mostrar()
