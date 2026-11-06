extends Node3D

# ============================================================================
#  PARI CARDS - NIVEL 1
# ----------------------------------------------------------------------------
#  Juego de emparejar fichas 3D sobre un tablero con cámara fija y vista
#  cenital. El tablero se genera proceduralmente en 5 capas (layers). Cada
#  capa es una grilla circular recortada de una red hexagonal en la que las
#  fichas se tocan entre sí. Las capas impares tienen una ficha en el
#  epicentro; las pares se desplazan al hueco triangular, de modo que el
#  epicentro queda vacío y cada capa se intercala con la anterior.
#
#  Cada ficha usa assets/models/ficha.glb como base genérica y recibe en su
#  cara superior la textura de una ficha (ficha_01.webp ... ficha_20.webp).
#
#  Regla de visibilidad:
#    Una ficha sólo puede tocarse si ninguna ficha de una capa superior
#    (número de capa menor) se superpone a su área.
#
#  Barra inferior:
#    5 espacios. Al tocar una ficha libre, ésta vuela a la barra. Si entra
#    una ficha del mismo tipo que otra ya presente, ambas desaparecen.
#    Si la barra llega a 5 fichas sin haber formado pareja, se pierde.
# ============================================================================

# --- Constantes de la grilla circular y capas -------------------------------
# Radio máximo de cada capa, en múltiplos del diámetro de la ficha. Recortar
# la red hexagonal con este radio produce una grilla circular.
const RADIO_MAX_CAPA: float = 2.1
const LAYER_COUNT: int = 5                # Capas totales (1 = superior).
const TIPOS_CARTA: int = 20               # ficha_01.webp ... ficha_20.webp.
const CAPACIDAD_BARRA: int = 5            # Espacios de la barra inferior.

# Slots de la barra y render 3D de la ficha que muestran. Las fichas
# acumuladas y sus placeholders se dibujan un 30% más grandes.
const ESCALA_FICHAS_BARRA: float = 1.3
const TAMANO_SLOT_BARRA := Vector2(96.0, 96.0) * ESCALA_FICHAS_BARRA
const MARGEN_ICONO_BARRA: float = 3.0 * ESCALA_FICHAS_BARRA
const TAMANO_CAMARA_ICONO: float = 0.14

# Altura de la barra inferior, en píxeles lógicos de la pantalla.
const ALTO_BARRA: float = 200.0

# Oscurecimiento de las fichas bloqueadas. La capa 1 se queda en 10% y las
# capas 2-5 llevan 10% extra: 30%, 40%, 50% y 60%. Índice 0 = capa 1.
const OSCURIDAD_POR_CAPA: Array[float] = [0.10, 0.30, 0.40, 0.50, 0.60]

# --- Constantes geométricas -------------------------------------------------
# Altura de la superficie del piso (CSGBox3D "Piso" de main.tscn).
const ALTURA_PISO: float = -0.04

# La barra es un quad 3D apenas por encima del piso: así las fichas, que
# siempre están más altas, quedan por delante y no las tapa.
const ALTURA_BARRA_3D: float = ALTURA_PISO + 0.002

# Ficha 3D genérica y shader que pinta su cara superior.
const FICHA_ESCENA: PackedScene = preload("res://assets/models/ficha.glb")
const SHADER_CARA: Shader = preload("res://shaders/ficha_cara.gdshader")

# Diámetro y grosor de la ficha. La separación entre capas deja un pequeño
# aire para que las fichas no se intersecten al apilarse.
const DIAMETRO_FICHA: float = 0.132
const GROSOR_FICHA: float = 0.022
const SEPARACION_CAPAS: float = 0.026

# Distancia entre los centros de fichas de una misma capa. Igual al diámetro
# para que queden pegadas, formando un empaquetado hexagonal.
const SEPARACION_FICHAS: float = DIAMETRO_FICHA

# Raíz de 3, usada para la geometría de la red hexagonal.
const SQRT3: float = 1.7320508075688772

# Desplazamiento de la red de las capas pares, en unidades de diámetro: media
# ficha en X y √3/6 en Y. Coincide con el centro del hueco triangular que
# dejan tres fichas contiguas, así que el epicentro de la capa queda vacío.
const DESPLAZAMIENTO_INTERCALADO := Vector2(0.5, 0.28867513459481287)

# Duración del vuelo de una ficha desde el tablero hasta la barra.
const DURACION_VUELO: float = 1.1

# Pequeño salto vertical al seleccionar una ficha, antes de viajar a la barra.
const ALTURA_SALTO_SELECCION: float = DIAMETRO_FICHA * 1.2
const DURACION_SALTO: float = DURACION_VUELO * 0.18

# Centro visual del tablero. Se desplaza ligeramente en Z para que la grilla
# circular quede centrada entre el HUD superior y la barra inferior.
const CENTRO_TABLERO := Vector3(0.0, 0.0, 0.16)

# Capa de física exclusiva para las cartas (bit 2). Evita que el raycast
# choque con el piso o con otros objetos de la escena.
const CAPA_COLISION_CARTAS: int = 2

# Ruta de las texturas. ficha_01.webp ... ficha_20.webp.
const RUTA_CARTA: String = "res://assets/images/fichas/ficha_%02d.webp"

# ============================================================================
#  CLASE INTERNA: CartaTablero
# ----------------------------------------------------------------------------
#  Nodo 3D que representa una ficha. Contiene:
#    - La malla de assets/models/ficha.glb, cuya cara superior ya trae la
#      textura de la carta asignada por main.gd.
#    - Un StaticBody3D con CylinderShape3D para poder seleccionarla con raycast.
#    - Datos lógicos: tipo, capa, celda axial y estado de visibilidad.
# ============================================================================
class CartaTablero extends Node3D:
	var tipo: int = 0
	var capa: int = 0
	var celda: Vector2i = Vector2i.ZERO
	var textura: Texture2D = null
	var material: ShaderMaterial = null
	var cuerpo: StaticBody3D = null
	var libre: bool = false

	# Incorpora la ficha ya configurada y crea su caja de colisión.
	# Recibe las medidas desde main.gd para que la clase interna no dependa
	# de las constantes de la clase exterior.
	func construir(
		p_tipo: int,
		p_capa: int,
		p_celda: Vector2i,
		p_textura: Texture2D,
		p_ficha: Node3D,
		p_material_cara: ShaderMaterial,
		p_diametro: float,
		p_grosor: float,
		p_capa_colision: int
	) -> void:
		tipo = p_tipo
		capa = p_capa
		celda = p_celda
		textura = p_textura
		material = p_material_cara

		# La ficha ya viene escalada y desplazada para que el centro de su
		# cara superior coincida con el origen de este nodo.
		add_child(p_ficha)

		# --- Colisión para el raycast ----------------------------------------
		cuerpo = StaticBody3D.new()
		cuerpo.name = "Cuerpo"
		cuerpo.collision_layer = p_capa_colision
		cuerpo.collision_mask = 0

		var forma := CollisionShape3D.new()
		forma.name = "Forma"
		var cilindro := CylinderShape3D.new()
		# El cilindro ocupa el volumen de la ficha: de su base a la cara
		# superior.
		cilindro.radius = p_diametro * 0.5
		cilindro.height = p_grosor
		forma.shape = cilindro
		forma.position = Vector3(0.0, -p_grosor * 0.5, 0.0)
		cuerpo.add_child(forma)

		# El cuerpo guarda una referencia a esta ficha para que el raycast
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

var _cartas_tablero: Array[CartaTablero] = []   # Sólo fichas aún en el tablero.
var _texturas: Array[Texture2D] = []            # Cache de las 20 texturas.

# Configuración de la ficha 3D, calculada una vez a partir del GLB.
var _radio_ficha: float = 1.0
var _escala_ficha: Vector3 = Vector3.ONE
var _offset_ficha: Vector3 = Vector3.ZERO
var _indice_cara_superior: int = 0

var _barra_tipos: Array[int] = []               # Tipos en la barra, en orden.
# Tipos que ya están en la barra lógica pero cuya ficha todavía está volando:
# su icono 3D permanece oculto hasta que termina la animación.
var _tipos_pendientes_visual: Array[int] = []
var _pares_encontrados: int = 0
var _juego_terminado: bool = false

# Reparto calculado a partir de las capacidades de cada grilla.
var _cartas_por_capa: Array[int] = []
var _total_cartas: int = 0
var _total_pares: int = 0

# Nodos de UI creados por código para no exigir cambios en main.tscn.
var _barra_ui: Control = null
var _barra_viewport: SubViewport = null
var _barra_sprite: Sprite3D = null
var _capa_efectos: Control = null
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

	nivel_actual = save_manager.nivel_actual_seleccionado

	# Ficha 3D, texturas, barra inferior y capa de efectos visuales.
	_preparar_ficha()
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

# Lee la malla base de ficha.glb y calcula la escala, el desplazamiento y la
# superficie que se usará como cara. Se ejecuta una sola vez por nivel.
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

	# El nodo de la ficha representa su cara superior: se baja la malla para
	# que la tapa quede en y = 0 y el cuerpo crezca hacia abajo.
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

# Busca la superficie de la cara superior. Primero intenta por el nombre del
# material y, si el importador lo pierde, por la cantidad de normales +Y.
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

# Configura una instancia de ficha.glb para que su cara superior muestre la
# textura indicada. Devuelve el material de la cara para poder cambiar la
# textura después (por ejemplo, en los iconos de la barra).
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

# Entorno mínimo para renderizar los iconos 3D de la barra con fondo
# transparente y una iluminación similar a la del tablero.
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
	_pares_encontrados = 0

	# Limpieza de estado anterior (reinicio).
	_barra_tipos.clear()
	_tipos_pendientes_visual.clear()
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
		var capacidad := _capacidad_capa(capa)
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
# Cada capa elige celdas distintas al azar de su red hexagonal recortada.
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
		var celdas := _generar_celdas(capa)

		# Se eligen celdas distintas para evitar dos cartas en la misma celda.
		celdas.shuffle()

		var cantidad: int = _cartas_por_capa[capa - 1]
		cantidad = mini(cantidad, celdas.size())

		for i in range(cantidad):
			if indice_tipo >= tipos.size():
				break
			_crear_carta(tipos[indice_tipo], capa, celdas[i])
			indice_tipo += 1

# Instancia una ficha, le asigna la textura de su tipo y la coloca en el mundo.
func _crear_carta(tipo: int, capa: int, celda: Vector2i) -> void:
	var textura := _textura_para_tipo(tipo)
	if textura == null:
		return

	var ficha := FICHA_ESCENA.instantiate() as Node3D
	var material_cara: ShaderMaterial = null
	if ficha != null:
		material_cara = _configurar_visual_ficha(ficha, textura)
	if ficha == null or material_cara == null:
		push_error("No se pudo instanciar la malla de ficha.glb")
		if ficha:
			ficha.free()
		return

	var carta := CartaTablero.new()
	carta.name = "Carta_L%d_Q%d_R%d" % [capa, celda.x, celda.y]
	carta.construir(
		tipo,
		capa,
		celda,
		textura,
		ficha,
		material_cara,
		DIAMETRO_FICHA,
		GROSOR_FICHA,
		CAPA_COLISION_CARTAS
	)

	contenedor_cartas.add_child(carta)
	carta.position = _posicion_mundo(celda, capa)
	_cartas_tablero.append(carta)

# Convierte una celda axial (q, r) y una capa a coordenadas 3D. Las capas
# pares suman el desplazamiento de intercalado: su red cae en los huecos
# triangulares de la capa superior y deja el epicentro vacío.
func _posicion_mundo(celda: Vector2i, capa: int) -> Vector3:
	var plano := (_axial_a_plano(celda) + _desplazamiento_capa(capa)) * SEPARACION_FICHAS
	return Vector3(
		CENTRO_TABLERO.x + plano.x,
		_y_para_capa(capa),
		CENTRO_TABLERO.z + plano.y
	)

# Altura de la cara superior de cada capa. La capa 1 es la superior; la 5,
# la inferior. La capa inferior se apoya sobre el piso.
func _y_para_capa(capa: int) -> float:
	return ALTURA_PISO \
		+ GROSOR_FICHA \
		+ float(LAYER_COUNT - capa) * SEPARACION_CAPAS

# Convierte coordenadas axiales de la red hexagonal a un punto del plano XZ.
# La unidad es un diámetro de ficha.
func _axial_a_plano(celda: Vector2i) -> Vector2:
	return Vector2(
		float(celda.x) + float(celda.y) * 0.5,
		float(celda.y) * SQRT3 * 0.5
	)

# Las capas impares llevan una ficha en el epicentro; las pares se desplazan
# al centro del hueco triangular que dejan tres fichas contiguas.
func _desplazamiento_capa(capa: int) -> Vector2:
	return Vector2.ZERO if capa % 2 == 1 else DESPLAZAMIENTO_INTERCALADO

# Celdas de una capa: todas las posiciones de la red hexagonal cuyo centro
# cae dentro del radio de la grilla circular.
func _generar_celdas(capa: int) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	var desplazamiento := _desplazamiento_capa(capa)
	var rango := ceili(RADIO_MAX_CAPA) + 2
	for r in range(-rango, rango + 1):
		for q in range(-rango, rango + 1):
			var celda := Vector2i(q, r)
			var plano := _axial_a_plano(celda) + desplazamiento
			if plano.length() <= RADIO_MAX_CAPA + 0.0001:
				celdas.append(celda)
	return celdas

# Capacidad total de una capa según su red hexagonal recortada.
func _capacidad_capa(capa: int) -> int:
	return _generar_celdas(capa).size()

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
# a su huella circular en el plano XZ.
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

# Comprueba si dos fichas redondas se superponen. Al ser círculos del mismo
# diámetro, basta comparar la distancia entre sus centros contra el diámetro.
func _se_superponen(a: CartaTablero, b: CartaTablero) -> bool:
	var dx := a.global_position.x - b.global_position.x
	var dz := a.global_position.z - b.global_position.z
	const EPSILON: float = 0.0001
	return sqrt(dx * dx + dz * dz) < DIAMETRO_FICHA - EPSILON

# Feedback visual: las fichas tapadas se muestran oscurecidas.
func _aplicar_estado_visual(carta: CartaTablero) -> void:
	if carta.material == null:
		return

	# Las fichas libres conservan su brillo original.
	var brillo := 1.0
	if not carta.libre:
		# Las bloqueadas se oscurecen según la capa a la que pertenecen.
		var indice := clampi(carta.capa - 1, 0, OSCURIDAD_POR_CAPA.size() - 1)
		brillo = 1.0 - OSCURIDAD_POR_CAPA[indice]

	carta.material.set_shader_parameter("brillo", brillo)

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

	# Si ya hay una ficha del mismo tipo, el vuelo apunta a ese espacio.
	var indice_destino: int = _barra_tipos.size()
	var indice_match := _barra_tipos.find(tipo)
	if indice_match != -1:
		indice_destino = indice_match

	# La ficha 3D seleccionada vuela hasta la barra; la animación la libera al
	# terminar. Se quita del tablero de inmediato para que no pueda volver a
	# seleccionarse mientras está en el aire.
	var resolver_pareja := indice_match != -1
	_animar_carta_a_barra(carta, indice_destino, resolver_pareja)

	if audio_juego:
		audio_juego.play_aleatorio("Pik")

	_cartas_tablero.erase(carta)
	carta.libre = false
	if carta.cuerpo:
		carta.cuerpo.collision_layer = 0

	# Al quitar esta carta pueden quedar libres cartas de capas inferiores.
	_actualizar_visibilidad()

	# Si la ficha ocupa un hueco nuevo, su icono se mantiene oculto hasta que
	# termina el vuelo. Las parejas no dejan un icono nuevo en la barra.
	if indice_match == -1:
		_tipos_pendientes_visual.append(tipo)
		# Resolución de la barra (pareja, derrota o victoria).
		_agregar_a_barra(tipo)

# ============================================================================
#  BARRA INFERIOR ("SCRABBLE BAR")
# ============================================================================
# Crea por código la barra de 5 espacios en la parte inferior de la pantalla.
# Se renderiza en un quad 3D apoyado en el piso para que las fichas queden
# siempre por encima de ella.
func _crear_barra_ui() -> void:
	_slots.clear()
	_slots_texturas.clear()
	_slots_viewports.clear()
	_slots_fichas.clear()
	_slots_materiales.clear()

	var entorno_ficha := _crear_entorno_ficha()
	var textura_inicial: Texture2D = null
	if not _texturas.is_empty():
		textura_inicial = _texturas[0]

	_barra_ui = Control.new()
	_barra_ui.name = "BarraRecoleccion"
	_barra_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dentro de su SubViewport la barra ocupa todo el rectángulo.
	_barra_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

		# Vista 3D aislada por slot. Se renderiza solo cuando cambia su
		# contenido para no gastar un render 3D extra cada frame.
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

		caja.add_child(slot)
		_slots.append(slot)
		_slots_texturas.append(icono)
		_slots_viewports.append(viewport)
		_slots_fichas.append(ficha)
		_slots_materiales.append(material_ficha)

	# La barra se dibuja en un quad 3D sobre el piso, alineado con el
	# rectángulo inferior de la pantalla. Al estar por debajo de todas las
	# fichas, éstas ya no quedan tapadas al llegar a los slots.
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

	_actualizar_barra_ui()

# Ajusta el quad 3D de la barra al rectángulo inferior de la pantalla. Como
# la cámara mira hacia abajo, el plano del piso es paralelo al de la imagen:
# proyectando sus esquinas se obtienen el centro y el tamaño exactos.
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
		var textura: Texture2D = null
		if i < _barra_tipos.size():
			tipo = _barra_tipos[i]
			textura = _textura_para_tipo(tipo)
		var pendiente := textura != null and _tipos_pendientes_visual.has(tipo)

		if textura != null and ficha != null and material != null:
			# Se renderiza desde ya, pero oculto, para que al revelarlo el
			# icono ya tenga la textura correcta (sin un frame con la anterior).
			icono.texture = viewport.get_texture()
			icono.visible = not pendiente
			ficha.visible = true
			material.set_shader_parameter("albedo_textura", textura)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			icono.visible = false
			if ficha:
				ficha.visible = false
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

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

# Anima la ficha 3D seleccionada desde su posición en el tablero hasta el
# centro del slot correspondiente de la barra. La ficha se lanza en arco y
# gira como una moneda al aire mientras se encoge para encajar en el espacio;
# al terminar el vuelo se libera y se muestra el icono del slot.
func _animar_carta_a_barra(carta: CartaTablero, indice_slot: int, resolver_pareja: bool = false) -> void:
	if _slots.is_empty() or camara == null:
		carta.queue_free()
		if resolver_pareja:
			_resolver_pareja_en_barra(indice_slot)
		return

	var slot := _slots[clampi(indice_slot, 0, _slots.size() - 1)]
	# El slot vive dentro del viewport de la barra: se traslada su centro al
	# rectángulo que la barra ocupa en la pantalla.
	var rect_slot := slot.get_global_rect()
	var pantalla := get_viewport().get_visible_rect().size
	var centro_slot := Vector2(
		rect_slot.get_center().x,
		pantalla.y - ALTO_BARRA + rect_slot.get_center().y
	)

	# Punto del mundo que, visto por la cámara, coincide con el centro del
	# slot. Se usa un plano horizontal a la altura de la ficha para conservar
	# su altura durante el vuelo.
	var plano := Plane(Vector3.UP, carta.global_position.y)
	var interseccion: Variant = plano.intersects_ray(
		camara.project_ray_origin(centro_slot),
		camara.project_ray_normal(centro_slot)
	)
	if interseccion == null:
		carta.queue_free()
		if resolver_pareja:
			_resolver_pareja_en_barra(indice_slot)
		return

	var destino: Vector3 = interseccion

	# Escala final para que el diámetro de la ficha coincida con el icono 3D
	# que se muestra dentro del slot.
	var radio := DIAMETRO_FICHA * 0.5
	var ancho_token := camara.unproject_position(destino + Vector3(radio, 0.0, 0.0)) \
		.distance_to(camara.unproject_position(destino - Vector3(radio, 0.0, 0.0)))
	var ancho_icono := (slot.size.x - MARGEN_ICONO_BARRA * 2.0) \
		* (DIAMETRO_FICHA / TAMANO_CAMARA_ICONO)
	var escala_final := 1.0
	if ancho_token > 0.001:
		escala_final = clampf(ancho_icono / ancho_token, 0.3, 1.0)

	# Arco del lanzamiento: la ficha sube mientras viaja y baja al llegar.
	var origen: Vector3 = carta.global_position
	var distancia := origen.distance_to(destino)
	var altura_arco := clampf(distancia * 0.25, 0.05, 0.18)

	# El vuelo parte desde lo alto del salto inicial.
	var origen_vuelo := origen + Vector3(0.0, ALTURA_SALTO_SELECCION, 0.0)
	var mover := func(t: float) -> void:
		var pos := origen_vuelo.lerp(destino, t)
		pos.y += sin(t * PI) * altura_arco
		carta.global_position = pos

	var tween := carta.create_tween()
	# 1) Salto vertical en el sitio, como preparación del lanzamiento.
	tween.tween_property(carta, "global_position:y", origen_vuelo.y, DURACION_SALTO) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	# 2) Vuelo hacia la barra; comienza al terminar el salto.
	tween.chain().tween_method(mover, 0.0, 1.0, DURACION_VUELO) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	# Dos vueltas completas sobre el eje X: termina de nuevo con la cara
	# hacia arriba, como una moneda que cae de canto y vuelve a su posición.
	tween.tween_property(carta, "rotation:x", -TAU * 2.0, DURACION_VUELO) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(carta, "scale", Vector3.ONE * escala_final, DURACION_VUELO) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	var tipo := carta.tipo
	tween.finished.connect(func() -> void:
		carta.queue_free()
		if resolver_pareja:
			_resolver_pareja_en_barra(indice_slot)
		else:
			_revelar_ficha_en_barra(tipo)
	)

func _resolver_pareja_en_barra(indice_slot: int) -> void:
	if _juego_terminado:
		return
	_barra_tipos.remove_at(indice_slot)
	_pares_encontrados += 1
	if audio_juego:
		audio_juego.play("Points")
	_actualizar_barra_ui()
	if _pares_encontrados >= _total_pares \
	and _cartas_tablero.is_empty() \
	and _barra_tipos.is_empty():
		_finalizar_partida(true)

# Muestra el icono de la ficha que acaba de aterrizar en la barra. Si otra
# ficha del mismo tipo sigue volando, el icono permanece oculto.
func _revelar_ficha_en_barra(tipo: int) -> void:
	var indice := _tipos_pendientes_visual.find(tipo)
	if indice == -1:
		return
	_tipos_pendientes_visual.remove_at(indice)
	_actualizar_barra_ui()

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
