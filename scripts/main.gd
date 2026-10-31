extends Node3D

# ============================================================================
#  PARI CARDS - NIVEL 1
# ----------------------------------------------------------------------------
#  Juego de emparejar cartas sobre un tablero 3D con cámara fija y vista
#  cenital. El tablero se genera proceduralmente en 5 capas (layers) con
#  grillas alternadas: las capas impares (1, 3, 5) usan 5x5 y las pares
#  (2, 4) usan 6x6. Ambas grillas comparten centro, por lo que las capas
#  6x6 quedan intercaladas y sobresalen media carta por cada lado.
#
#  Regla de visibilidad:
#    Una carta sólo puede tocarse si ninguna carta de una capa superior
#    (número de capa menor) se superpone a su área.
#
#  Barra inferior:
#    5 espacios. Al tocar una carta libre, ésta vuela a la barra. Si entra
#    una carta del mismo tipo que otra ya presente, ambas desaparecen.
#    Si la barra llega a 5 cartas sin haber formado pareja, se pierde.
# ============================================================================

# --- Constantes de grilla y capas -------------------------------------------
const GRID_IMPAR: int = 5                 # Lado de las capas 1, 3 y 5.
const GRID_PAR: int = 6                   # Lado de las capas 2 y 4.
const LAYER_COUNT: int = 5                # Capas totales (1 = superior).
const TIPOS_CARTA: int = 20               # carta_01.png ... carta_20.png.
const CAPACIDAD_BARRA: int = 5            # Espacios de la barra inferior.

# Oscurecimiento de las cartas bloqueadas según su capa. Índice 0 = capa 1.
const OSCURIDAD_POR_CAPA: Array[float] = [0.05, 0.15, 0.25, 0.35, 0.45]

# --- Constantes geométricas -------------------------------------------------
# Tamaño de una celda (y de una carta) en unidades del mundo 3D.
# La proporción 0.14 x 0.21 respeta el aspecto 2:3 de los PNG (360x540).
const TAMANO_CELDA := Vector2(0.14, 0.21)

# Altura de la superficie del piso (CSGBox3D "Piso" de main.tscn).
const ALTURA_PISO: float = -0.04

# Separación vertical entre capas y grosor de la caja de colisión de la carta.
const SEPARACION_CAPAS: float = 0.008
const GROSOR_CARTA: float = 0.004

# Centro visual del tablero. Se desplaza ligeramente en Z para que la grilla
# 6x6 quede centrada entre el HUD superior y la barra inferior.
const CENTRO_TABLERO := Vector3(0.0, 0.0, 0.16)

# Capa de física exclusiva para las cartas (bit 2). Evita que el raycast
# choque con el piso o con otros objetos de la escena.
const CAPA_COLISION_CARTAS: int = 2

# Ruta de las texturas. carta_01.png ... carta_20.png.
const RUTA_CARTA: String = "res://assets/images/cards/carta_%02d.png"

# ============================================================================
#  CLASE INTERNA: CartaTablero
# ----------------------------------------------------------------------------
#  Nodo 3D que representa una carta. Contiene:
#    - Un QuadMesh horizontal con la textura de la carta.
#    - Un StaticBody3D con BoxShape3D para poder seleccionarla con raycast.
#    - Datos lógicos: tipo, capa, columna, fila y estado de visibilidad.
# ============================================================================
class CartaTablero extends Node3D:
	var tipo: int = 0
	var capa: int = 0
	var col: int = 0
	var fila: int = 0
	var textura: Texture2D = null
	var material: StandardMaterial3D = null
	var cuerpo: StaticBody3D = null
	var libre: bool = false

	# Construye la malla, el material y la caja de colisión de la carta.
	# Recibe las medidas desde main.gd para que la clase interna no dependa
	# de las constantes de la clase exterior.
	func construir(
		p_tipo: int,
		p_capa: int,
		p_col: int,
		p_fila: int,
		p_textura: Texture2D,
		p_tamano: Vector2,
		p_grosor: float,
		p_capa_colision: int
	) -> void:
		tipo = p_tipo
		capa = p_capa
		col = p_col
		fila = p_fila
		textura = p_textura

		# --- Malla horizontal -------------------------------------------------
		var quad := QuadMesh.new()
		quad.size = p_tamano

		var malla := MeshInstance3D.new()
		malla.name = "Malla"
		malla.mesh = quad
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Material sin iluminación para que el arte de la carta conserve sus
		# colores originales. Alpha scissor evita problemas de ordenamiento
		# con las transparencias del PNG.
		material = StandardMaterial3D.new()
		material.albedo_texture = p_textura
		material.albedo_color = Color.WHITE
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		malla.material_override = material

		add_child(malla)

		# La cámara mira hacia abajo y su "arriba" es +Z. Esta rotación deja
		# el QuadMesh plano sobre el piso, con la textura orientada como en
		# pantalla (sin espejado ni giro de 180°).
		basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI * 0.5)

		# --- Colisión para el raycast ----------------------------------------
		cuerpo = StaticBody3D.new()
		cuerpo.name = "Cuerpo"
		cuerpo.collision_layer = p_capa_colision
		cuerpo.collision_mask = 0

		var forma := CollisionShape3D.new()
		forma.name = "Forma"
		var caja := BoxShape3D.new()
		# En el espacio local de la carta: X = ancho, Y = alto, Z = grosor.
		# La rotación del nodo convierte Y local en Z del mundo y Z local en Y.
		caja.size = Vector3(p_tamano.x, p_tamano.y, p_grosor)
		forma.shape = caja
		cuerpo.add_child(forma)

		# El cuerpo guarda una referencia a esta carta para que el raycast
		# pueda recuperarla desde el colisionador.
		cuerpo.set_meta("carta", self)
		add_child(cuerpo)

# ============================================================================
#  NODOS DE LA ESCENA
# ============================================================================
@onready var contenedor_cartas: Node3D = $BoardElements
@onready var camara: Camera3D = $Camera3D

@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego
@onready var boton_pausa: TextureButton = $UI/BotonPausa
@onready var panel_pausa: PanelPausa = $UI/PanelPausa as PanelPausa

# ============================================================================
#  ESTADO DEL JUEGO
# ============================================================================
var nivel_actual: int = 1
var ctrl_resultados: ControladorResultados

var _cartas_tablero: Array[CartaTablero] = []   # Sólo cartas aún en el tablero.
var _texturas: Array[Texture2D] = []            # Cache de las 20 texturas.

var _barra_tipos: Array[int] = []               # Tipos en la barra, en orden.
var _pares_encontrados: int = 0
var _juego_terminado: bool = false

# Reparto calculado a partir de las capacidades de cada grilla.
var _cartas_por_capa: Array[int] = []
var _total_cartas: int = 0
var _total_pares: int = 0

# Nodos de UI creados por código para no exigir cambios en main.tscn.
var _barra_ui: Control = null
var _capa_efectos: Control = null
var _slots: Array[Panel] = []
var _slots_texturas: Array[TextureRect] = []

# ============================================================================
#  CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	randomize()

	nivel_actual = save_manager.nivel_actual_seleccionado

	# Texturas, barra inferior y capa de efectos visuales.
	_cargar_texturas()
	_crear_barra_ui()
	_crear_capa_efectos()
	_preparar_titulo()

	# Controlador reutilizable de resultados (panel de fin de nivel).
	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	ctrl_resultados.configurar(
		panel_resultados,
		[ui_level_number, boton_pausa, _barra_ui],
		ui_level_number,
		reiniciar_nivel
	)

	# Conexión defensiva por si la escena ya trae la señal conectada.
	if boton_pausa and not boton_pausa.is_connected("pressed", _on_boton_pausa_pressed):
		boton_pausa.pressed.connect(_on_boton_pausa_pressed)

	_preparar_reparto()
	_cargar_nivel(nivel_actual)

# ============================================================================
#  CARGA DE RECURSOS
# ============================================================================
func _cargar_texturas() -> void:
	_texturas.clear()
	for i in range(1, TIPOS_CARTA + 1):
		var ruta := RUTA_CARTA % i
		var textura := load(ruta) as Texture2D
		if textura == null:
			push_error("No se pudo cargar la textura de carta: %s" % ruta)
		_texturas.append(textura)

func _textura_para_tipo(tipo: int) -> Texture2D:
	var indice := tipo - 1
	if indice < 0 or indice >= _texturas.size():
		return null
	return _texturas[indice]

# ============================================================================
#  GENERACIÓN PROCEDURAL DEL NIVEL
# ============================================================================
func _cargar_nivel(n: int) -> void:
	_juego_terminado = false
	_pares_encontrados = 0

	# Limpieza de estado anterior (reinicio).
	_barra_tipos.clear()
	_actualizar_barra_ui()
	_limpiar_tablero()
	_limpiar_efectos()

	if ui_level_title:
		ui_level_title.visible = false
	if ctrl_resultados:
		ctrl_resultados.reset()
	if ui_level_number:
		ui_level_number.establecer_nivel(n)

	_generar_cartas()
	_actualizar_visibilidad()

# Calcula cuántas cartas caben en cada capa y ajusta el total a un número par.
func _preparar_reparto() -> void:
	_cartas_por_capa.clear()
	var total := 0

	for capa in range(1, LAYER_COUNT + 1):
		var lado := _lado_grilla(capa)
		var capacidad := lado * lado
		_cartas_por_capa.append(capacidad)
		total += capacidad

	# Las parejas exigen un total par. Si la suma de capacidades es impar,
	# se deja una celda vacía en la capa inferior (la menos visible).
	if total % 2 != 0:
		_cartas_por_capa[LAYER_COUNT - 1] -= 1
		total -= 1

	_total_cartas = total
	_total_pares = total / 2
	print("Reparto: capas=", _cartas_por_capa, " total=", _total_cartas, " pares=", _total_pares)

# Crea las parejas necesarias para llenar las grillas y las reparte entre capas.
# Cada capa elige celdas distintas al azar dentro de su grilla (5x5 o 6x6).
func _generar_cartas() -> void:
	var tipos: Array[int] = []

	# Cada pareja se agrega dos veces para que siempre haya match.
	for _i in range(_total_pares):
		var tipo := randi_range(1, TIPOS_CARTA)
		tipos.append(tipo)
		tipos.append(tipo)

	# El orden aleatorio evita que las parejas queden juntas por capa.
	tipos.shuffle()

	var indice_tipo: int = 0

	for capa in range(1, LAYER_COUNT + 1):
		var lado := _lado_grilla(capa)

		# Todas las celdas posibles de esta capa.
		var celdas: Array[Vector2i] = []
		for fila in range(lado):
			for col in range(lado):
				celdas.append(Vector2i(col, fila))

		# Se eligen celdas distintas para evitar dos cartas en la misma celda.
		celdas.shuffle()

		var cantidad: int = _cartas_por_capa[capa - 1]
		cantidad = mini(cantidad, celdas.size())

		for i in range(cantidad):
			if indice_tipo >= tipos.size():
				break
			var celda := celdas[i]
			_crear_carta(tipos[indice_tipo], capa, celda.x, celda.y)
			indice_tipo += 1

# Instancia una carta y la coloca en su posición del mundo.
func _crear_carta(tipo: int, capa: int, col: int, fila: int) -> void:
	var textura := _textura_para_tipo(tipo)
	if textura == null:
		return

	var carta := CartaTablero.new()
	carta.name = "Carta_L%d_%d_%d" % [capa, col, fila]
	carta.construir(
		tipo,
		capa,
		col,
		fila,
		textura,
		TAMANO_CELDA,
		GROSOR_CARTA,
		CAPA_COLISION_CARTAS
	)

	contenedor_cartas.add_child(carta)
	carta.position = _posicion_mundo(col, fila, capa)
	_cartas_tablero.append(carta)

# Convierte una celda lógica (columna, fila) y una capa a coordenadas 3D.
#
# La cámara está rotada 180° en X respecto a la pantalla: su derecha es -X
# y su arriba es +Z. Por eso la columna crece hacia -X y la fila hacia -Z.
func _posicion_mundo(col: int, fila: int, capa: int) -> Vector3:
	var lado := _lado_grilla(capa)
	var x_logica := (float(col) - (float(lado) - 1.0) * 0.5) * TAMANO_CELDA.x
	var y_logica := (float(fila) - (float(lado) - 1.0) * 0.5) * TAMANO_CELDA.y

	# Ambas grillas comparten centro. Como la capa par tiene una columna y una
	# fila extra, sus centros quedan intercalados media celda respecto de la
	# capa impar y sus bordes sobresalen media carta por cada lado.
	return Vector3(
		CENTRO_TABLERO.x - x_logica,
		_y_para_capa(capa),
		CENTRO_TABLERO.z - y_logica
	)

# Altura de cada capa. La capa 1 es la superior; la 5, la inferior.
func _y_para_capa(capa: int) -> float:
	return ALTURA_PISO \
		+ float(LAYER_COUNT - capa) * SEPARACION_CAPAS \
		+ GROSOR_CARTA * 0.5

func _es_capa_par(capa: int) -> bool:
	return capa % 2 == 0

# Las capas 2 y 4 usan una grilla 6x6; las capas 1, 3 y 5 usan 5x5.
func _lado_grilla(capa: int) -> int:
	return GRID_PAR if _es_capa_par(capa) else GRID_IMPAR

# ============================================================================
#  VISIBILIDAD (OVERLAP CHECK)
# ============================================================================
# Recalcula qué cartas están libres. Se llama después de generar el tablero
# y después de retirar una carta, porque al eliminar una capa superior las
# cartas de abajo pueden quedar destapadas.
func _actualizar_visibilidad() -> void:
	for carta in _cartas_tablero:
		carta.libre = _esta_libre(carta)
		_aplicar_estado_visual(carta)

# Una carta está libre si ninguna carta de una capa superior se superpone
# a su huella rectangular en el plano XZ.
func _esta_libre(carta: CartaTablero) -> bool:
	for otra in _cartas_tablero:
		if otra == carta:
			continue
		# Capa 1 es la más alta. Sólo las capas con número menor tapan.
		if otra.capa >= carta.capa:
			continue
		if _se_superponen(carta, otra):
			return false
	return true

# Comprueba si dos cartas comparten área. Todas tienen el mismo tamaño, así
# que basta comparar la distancia entre centros contra el tamaño de celda.
func _se_superponen(a: CartaTablero, b: CartaTablero) -> bool:
	var dx := absf(a.global_position.x - b.global_position.x)
	var dz := absf(a.global_position.z - b.global_position.z)
	const EPSILON: float = 0.0001
	return dx < TAMANO_CELDA.x - EPSILON and dz < TAMANO_CELDA.y - EPSILON

# Feedback visual: las cartas tapadas se muestran oscurecidas.
func _aplicar_estado_visual(carta: CartaTablero) -> void:
	if carta.material == null:
		return

	# Las cartas libres conservan su brillo original.
	if carta.libre:
		carta.material.albedo_color = Color.WHITE
		return

	# Las bloqueadas se oscurecen según la capa a la que pertenecen.
	var indice := clampi(carta.capa - 1, 0, OSCURIDAD_POR_CAPA.size() - 1)
	var brillo := 1.0 - OSCURIDAD_POR_CAPA[indice]
	carta.material.albedo_color = Color(brillo, brillo, brillo, 1.0)

# ============================================================================
#  INPUT Y SELECCIÓN
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _juego_terminado or get_tree().paused:
		return
	if panel_resultados and panel_resultados.visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_intentar_seleccionar(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		# En móvil se usan eventos táctiles. En escritorio, el mouse.
		if event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed \
		and not DisplayServer.is_touchscreen_available():
			_intentar_seleccionar(event.position)
			get_viewport().set_input_as_handled()

func _intentar_seleccionar(pos_2d: Vector2) -> void:
	if _juego_terminado:
		return

	var carta := _carta_bajo_punto(pos_2d)
	if carta == null:
		return

	# La carta debe estar totalmente libre para poder tocarse.
	if not carta.libre:
		return

	_seleccionar_carta(carta)

# Lanza un rayo desde la cámara y devuelve la carta más cercana que golpea.
# Como la cámara mira hacia abajo, la carta más cercana es la de capa superior.
func _carta_bajo_punto(pos_2d: Vector2) -> CartaTablero:
	if camara == null:
		return null

	var origen := camara.project_ray_origin(pos_2d)
	var direccion := camara.project_ray_normal(pos_2d)
	var destino := origen + direccion * 10.0

	var consulta := PhysicsRayQueryParameters3D.create(
		origen,
		destino,
		CAPA_COLISION_CARTAS
	)
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		return null

	var colisionador = resultado.get("collider")
	if colisionador == null or not colisionador.has_meta("carta"):
		return null

	var carta: CartaTablero = colisionador.get_meta("carta")
	return carta

func _seleccionar_carta(carta: CartaTablero) -> void:
	if _juego_terminado or not carta.libre:
		return

	var tipo := carta.tipo

	# Si ya hay una carta del mismo tipo, el fantasma vuela hacia ese espacio.
	var indice_destino: int = _barra_tipos.size()
	var indice_match := _barra_tipos.find(tipo)
	if indice_match != -1:
		indice_destino = indice_match

	# Animación visual desde la posición proyectada de la carta a la barra.
	_animar_carta_a_barra(carta, indice_destino)

	if audio_juego:
		audio_juego.play_aleatorio("Pik")

	# La carta desaparece del tablero inmediatamente.
	_cartas_tablero.erase(carta)
	carta.libre = false
	if carta.cuerpo:
		carta.cuerpo.collision_layer = 0
	carta.visible = false
	carta.queue_free()

	# Al quitar esta carta pueden quedar libres cartas de capas inferiores.
	_actualizar_visibilidad()

	# Resolución de la barra (pareja, derrota o victoria).
	_agregar_a_barra(tipo)

# ============================================================================
#  BARRA INFERIOR ("SCRABBLE BAR")
# ============================================================================
# Crea por código la barra de 5 espacios en la parte inferior de la pantalla.
# Se inserta al fondo del CanvasLayer para quedar debajo de los paneles.
func _crear_barra_ui() -> void:
	var ui := $UI as CanvasLayer
	if ui == null:
		return

	_slots.clear()
	_slots_texturas.clear()

	_barra_ui = Control.new()
	_barra_ui.name = "BarraRecoleccion"
	_barra_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anclada al borde inferior, 200 px de alto.
	_barra_ui.anchor_left = 0.0
	_barra_ui.anchor_top = 1.0
	_barra_ui.anchor_right = 1.0
	_barra_ui.anchor_bottom = 1.0
	_barra_ui.offset_left = 0.0
	_barra_ui.offset_top = -200.0
	_barra_ui.offset_right = 0.0
	_barra_ui.offset_bottom = 0.0

	# Fondo semitransparente.
	var fondo := ColorRect.new()
	fondo.name = "Fondo"
	fondo.color = Color(0.02, 0.02, 0.04, 0.62)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_ui.add_child(fondo)

	# Línea superior decorativa.
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

	# Contenedor horizontal centrado para los 5 espacios.
	var caja := HBoxContainer.new()
	caja.name = "Slots"
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 12)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_ui.add_child(caja)

	for _i in range(CAPACIDAD_BARRA):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(96, 144)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.08, 0.08, 0.12, 0.88)
		estilo.border_color = Color(0.95, 0.78, 0.25, 0.8)
		estilo.set_border_width_all(2)
		estilo.set_corner_radius_all(10)
		slot.add_theme_stylebox_override("panel", estilo)

		var textura_rect := TextureRect.new()
		textura_rect.name = "Carta"
		textura_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		textura_rect.offset_left = 3.0
		textura_rect.offset_top = 3.0
		textura_rect.offset_right = -3.0
		textura_rect.offset_bottom = -3.0
		textura_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		textura_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		textura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		textura_rect.visible = false
		slot.add_child(textura_rect)

		caja.add_child(slot)
		_slots.append(slot)
		_slots_texturas.append(textura_rect)

	ui.add_child(_barra_ui)
	# Al índice 0 para que PanelResultados y PanelPausa queden por encima.
	ui.move_child(_barra_ui, 0)

	_actualizar_barra_ui()

func _actualizar_barra_ui() -> void:
	for i in range(_slots.size()):
		var textura_rect := _slots_texturas[i]
		if i < _barra_tipos.size():
			var textura := _textura_para_tipo(_barra_tipos[i])
			textura_rect.texture = textura
			textura_rect.visible = textura != null
		else:
			textura_rect.texture = null
			textura_rect.visible = false

# Añade un tipo a la barra y resuelve la lógica de pareja / derrota.
func _agregar_a_barra(tipo: int) -> void:
	if _juego_terminado:
		return

	# Buscar una pareja antes de añadir la nueva carta.
	var indice_match := _barra_tipos.find(tipo)
	_barra_tipos.append(tipo)

	if indice_match != -1:
		# Pareja encontrada: desaparecen la carta existente y la recién llegada.
		_barra_tipos.remove_at(indice_match)
		_barra_tipos.pop_back()
		_pares_encontrados += 1
		if audio_juego:
			audio_juego.play("Points")
	else:
		# Sin pareja. Si la barra se llenó, es derrota.
		if _barra_tipos.size() >= CAPACIDAD_BARRA:
			_actualizar_barra_ui()
			_finalizar_partida(false)
			return

	_actualizar_barra_ui()

	# Victoria: se encontraron todos los pares y no queda nada en tablero ni barra.
	if _pares_encontrados >= _total_pares \
	and _cartas_tablero.is_empty() \
	and _barra_tipos.is_empty():
		_finalizar_partida(true)

# ============================================================================
#  EFECTOS VISUALES
# ============================================================================
func _crear_capa_efectos() -> void:
	var ui := $UI as CanvasLayer
	if ui == null:
		return

	_capa_efectos = Control.new()
	_capa_efectos.name = "CapaEfectos"
	_capa_efectos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa_efectos.mouse_filter = Control.MOUSE_FILTER_IGNORE

	ui.add_child(_capa_efectos)
	# Justo encima de la barra y debajo del resto de la UI.
	ui.move_child(_capa_efectos, 1)

func _limpiar_efectos() -> void:
	if _capa_efectos == null:
		return
	for hijo in _capa_efectos.get_children():
		_capa_efectos.remove_child(hijo)
		hijo.queue_free()

# Anima una copia 2D de la carta desde su posición en pantalla hasta el slot
# correspondiente de la barra. La carta 3D se oculta inmediatamente, de modo
# que el jugador percibe que la carta vuela del tablero a la barra.
func _animar_carta_a_barra(carta: CartaTablero, indice_slot: int) -> void:
	if _capa_efectos == null or _slots.is_empty() or camara == null:
		return

	# Coincide con el tamaño de los slots de la barra inferior.
	var tamano_fantasma := Vector2(96, 144)
	var origen := camara.unproject_position(carta.global_position) - tamano_fantasma * 0.5

	var fantasma := TextureRect.new()
	fantasma.texture = carta.textura
	fantasma.size = tamano_fantasma
	fantasma.position = origen
	fantasma.pivot_offset = tamano_fantasma * 0.5
	fantasma.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fantasma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fantasma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_efectos.add_child(fantasma)

	var slot := _slots[clampi(indice_slot, 0, _slots.size() - 1)]
	var destino := slot.get_global_rect().get_center() - tamano_fantasma * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fantasma, "position", destino, 0.22) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(fantasma, "scale", Vector2(1.15, 1.15), 0.22) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tween.finished.connect(fantasma.queue_free)

# ============================================================================
#  LIMPIEZA Y FIN DE PARTIDA
# ============================================================================
func _limpiar_tablero() -> void:
	_cartas_tablero.clear()
	if contenedor_cartas == null:
		return
	for hijo in contenedor_cartas.get_children():
		contenedor_cartas.remove_child(hijo)
		hijo.queue_free()

func _preparar_titulo() -> void:
	if ui_level_title == null:
		return
	# El LevelTitle de la escena es un placeholder. Se usa como mensaje
	# central de victoria/derrota, por eso empieza oculto.
	ui_level_title.visible = false
	ui_level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_level_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_level_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _mostrar_mensaje_final(texto: String) -> void:
	if ui_level_title == null:
		return
	ui_level_title.text = texto
	ui_level_title.add_theme_font_size_override("font_size", 72)
	ui_level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_level_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_level_title.visible = true

func _finalizar_partida(victoria: bool) -> void:
	if _juego_terminado:
		return
	_juego_terminado = true

	if victoria:
		if audio_manager:
			audio_manager.play_welldone()
		_mostrar_mensaje_final("¡Nivel completado!")
	else:
		if audio_manager:
			audio_manager.play_fail()
		_mostrar_mensaje_final("¡Sin espacio!")

	# Breve pausa para leer el mensaje antes de abrir el panel de resultados.
	await get_tree().create_timer(1.2, false).timeout
	if not is_inside_tree():
		return

	if ui_level_title:
		ui_level_title.visible = false
	mostrar_panel_resultados()

func mostrar_panel_resultados() -> void:
	if ctrl_resultados:
		ctrl_resultados.mostrar(nivel_actual)

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
