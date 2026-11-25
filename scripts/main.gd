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
#  cara superior una textura de assets/images/astronomia.
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
const CAPACIDAD_BARRA: int = 5            # Espacios de la barra inferior.
const TIEMPO_COMBO: float = 2.0           # Ventana de tiempo (segundos) para seguir el combo.

# Rutas de configuración de niveles y tipos de fichas.
const RUTA_NIVELES: String = "res://data/niveles.json"
const RUTA_VALORES: String = "res://data/valores.json"
const RUTA_CARPETA_FICHAS: String = "res://assets/images/astronomia/"
const CAPAS_POR_DEFECTO: int = 5

# Slots de la barra y render 3D de la ficha que muestran. Las fichas
# acumuladas y sus placeholders se dibujan un 30% más grandes.
const ESCALA_FICHAS_BARRA: float = 1.3
const TAMANO_SLOT_BARRA := Vector2(96.0, 96.0) * ESCALA_FICHAS_BARRA
const MARGEN_ICONO_BARRA: float = 3.0 * ESCALA_FICHAS_BARRA
const TAMANO_CAMARA_ICONO: float = 0.14

# Altura de la barra inferior, en píxeles lógicos de la pantalla.
const ALTO_BARRA: float = 200.0

# Oscurecimiento base de fichas bloqueadas. Si un nivel tiene más capas que
# valores definidos, las capas extra usan el último valor de la lista.
const OSCURIDAD_BASE_CAPAS: Array[float] = [0.10, 0.30, 0.40, 0.50, 0.60]

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

# Capa de física exclusiva para las fichas (bit 2). Evita que el raycast
# choque con el piso o con otros objetos de la escena.
const CAPA_COLISION_FICHAS: int = 2

# Altura inicial (por encima de todo) desde la que cada ficha cae a su lugar.
const ALTURA_CAIDA_INICIAL: float = 4.0
# Duración de la caída de cada ficha.
const DURACION_CAIDA: float = 0.7
# Escalón de retraso entre capas (capas inferiores caen primero).
const ESCALON_CAIDA_POR_CAPA: float = 0.12
# Intervalo de inicio entre cada ficha (caída una por una).
const ESPACIO_ENTRE_FICHAS: float = 0.05

var _fichas_config: Dictionary = {}
const SMOKE_PUFF_2D: PackedScene = preload(
	"res://crisp_juice_fx/fx2d/elements/smoke_puff_2d.tscn"
)

# Escala del humo al resolver una pareja. Al ser 2D, este valor controla
# directamente el tamaño en pantalla del efecto.
const ESCALA_SMOKE_PUFF: float = 1.0

const PUNTOS_FLOTANTES_ESCENA: PackedScene = preload("res://scenes/puntos_flotantes.tscn")

# ============================================================================
#  CLASE INTERNA: FichaTablero
# ----------------------------------------------------------------------------
#  Nodo 3D que representa una ficha. Contiene:
#    - La malla de assets/models/ficha.glb, cuya cara superior ya trae la
#      textura de la ficha asignada por main.gd.
#    - Un StaticBody3D con CylinderShape3D para poder seleccionarla con raycast.
#    - Datos lógicos: tipo, capa, celda axial y estado de visibilidad.
# ============================================================================
class FichaTablero extends Node3D:
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
		cuerpo.set_meta("ficha", self)
		add_child(cuerpo)

# ============================================================================
#  NODOS DE LA ESCENA
# ============================================================================
@onready var contenedor_fichas: Node3D = $BoardElements
@onready var camara: Camera3D = $Camera3D

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

# Configuración cargada desde data/niveles.json y data/valores.json.
var _niveles_config: Dictionary = {}
var _valores_config: Dictionary = {}
var _capas_nivel: int = CAPAS_POR_DEFECTO
var _slots_nivel: int = CAPACIDAD_BARRA
var _tipos_nivel: Array[int] = []
var _fichas_n_nivel: int = 0
var _score_nivel: int = 0

# Patrón de distribución de fichas (configurable por nivel).
var _patron_tipo: String = "circulos"
var _patron_radio: float = RADIO_MAX_CAPA
var _patron_offset_impar: Vector2 = Vector2.ZERO
var _patron_offset_par: Vector2 = DESPLAZAMIENTO_INTERCALADO
var _patron_celdas_impar: Array[Vector2i] = []
var _patron_celdas_par: Array[Vector2i] = []
# Offset de centrado por capa (plano XZ). Centra cualquier patrón explícito
# (triángulos, formas arbitrarias) alrededor del origen del tablero. Los
# círculos ya tienen centroide en (0,0) por su fórmula, así que no varían.
var _patron_centro: Array[Vector2] = []

var _fichas_tablero: Array[FichaTablero] = []   # Sólo fichas aún en el tablero.
var _texturas: Array[Texture2D] = []            # Cache de las 20 texturas.

# Configuración de la ficha 3D, calculada una vez a partir del GLB.
var _radio_ficha: float = 1.0
var _escala_ficha: Vector3 = Vector3.ONE
var _offset_ficha: Vector3 = Vector3.ZERO
var _indice_cara_superior: int = 0

# Barra: array de tamaño fijo (una entrada por slot). 0 = slot vacío.
var _barra_tipos: Array[int] = []
# Cantidad acumulada por slot (1 = solitaria, >=2 = puede desaparecer al cerrarse la ventana).
var _barra_conteo: Array[int] = []
# Oculta el icono del slot mientras su primera ficha aún está en vuelo.
var _barra_icono_oculto: Array[bool] = []
# Estado del combo activo.
var _combo_activo: bool = false
var _combo_tipo: int = 0
var _combo_slot: int = -1
var _combo_contador: int = 0
var _timer_combo: Timer = null
# Fichas que están volando hacia la barra y aún no han aterrizado.
var _fichas_en_vuelo: Array[FichaTablero] = []
# Slots de la barra que tienen una ficha en vuelo (su icono no se muestra hasta aterrizar).
var _slots_en_vuelo: Array[int] = []
var _juego_terminado: bool = false
var _animando_entrada: bool = false
var _pendientes_entrada: int = 0

# Reparto calculado a partir de las capacidades de cada grilla.
var _fichas_por_capa: Array[int] = []
var _total_fichas: int = 0
var _total_pares: int = 0

# Nodos de UI creados por código para no exigir cambios en main.tscn.
var _barra_ui: Control = null
var _barra_viewport: SubViewport = null
var _barra_sprite: Sprite3D = null
var _barra_slots_box: HBoxContainer = null
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
	_cargar_configuracion()

	# Ficha 3D, texturas, barra inferior y capa de efectos visuales.
	_preparar_ficha()
	_configurar_nivel(nivel_actual)
	_cargar_texturas()
	_crear_barra_ui()
	_crear_capa_efectos()
	_preparar_titulo()
	_crear_timer_combo()

	# Controlador reutilizable de resultados (panel de fin de nivel).
	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	ctrl_resultados.configurar(
		panel_resultados,
		[ui_level_number, ui_puntaje, boton_pausa, _barra_ui],
		ui_level_number,
		reiniciar_nivel
	)

	# Conexión defensiva por si la escena ya trae la señal conectada.
	if boton_pausa and not boton_pausa.is_connected("pressed", _on_boton_pausa_pressed):
		boton_pausa.pressed.connect(_on_boton_pausa_pressed)

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

	# Patrón de distribución: por defecto "circulos" (hexagonal circular intercalado).
	_patron_tipo = "circulos"
	_patron_radio = RADIO_MAX_CAPA
	_patron_offset_impar = Vector2.ZERO
	_patron_offset_par = DESPLAZAMIENTO_INTERCALADO
	_patron_celdas_impar.clear()
	_patron_celdas_par.clear()
	var patron_cfg: Variant = nivel_cfg.get("patron", "circulos")
	if patron_cfg is String:
		_patron_tipo = str(patron_cfg)
	elif patron_cfg is Dictionary:
		_patron_tipo = str(patron_cfg.get("tipo", "circulos"))
		_patron_radio = float(patron_cfg.get("radio", RADIO_MAX_CAPA))
		var off_i: Variant = patron_cfg.get("offset_impar", null)
		if off_i is Array and off_i.size() >= 2:
			_patron_offset_impar = Vector2(float(off_i[0]), float(off_i[1]))
		var off_p: Variant = patron_cfg.get("offset_par", null)
		if off_p is Array and off_p.size() >= 2:
			_patron_offset_par = Vector2(float(off_p[0]), float(off_p[1]))
		_patron_celdas_impar = _parsear_celdas_patron(patron_cfg.get("celdas_impar", []))
		_patron_celdas_par = _parsear_celdas_patron(patron_cfg.get("celdas_par", patron_cfg.get("celdas", [])))

	# Centroide de centrado por capa (sobre celdas CRUDAS, sin offset de
	# intercalado). Los círculos ya están centrados por su fórmula; los
	# patrones explícitos se centran primero y luego se aplica el offset de
	# intercalado para que queden en los huecos sin perder el centro.
	_patron_centro.clear()
	for _capa in range(1, _capas_nivel + 1):
		var celdas := _generar_celdas(_capa)
		if celdas.is_empty():
			_patron_centro.append(Vector2.ZERO)
			continue
		var centro := Vector2.ZERO
		for celda in celdas:
			centro += _axial_a_plano(celda)
		centro /= float(celdas.size())
		_patron_centro.append(-centro)

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
		# Fallback: usar todos los tipos definidos en valores.json.
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
	_preparar_reparto()

	# Limpieza de estado anterior (reinicio).
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
	_limpiar_efectos()

	if ui_level_title:
		ui_level_title.visible = false
	if ctrl_resultados:
		ctrl_resultados.reset()
	if ui_level_number:
		ui_level_number.establecer_nivel(n)

	_generar_fichas()
	_animar_entrada_fichas()

# Calcula cuántas fichas caben en cada capa y ajusta el total a un número par.
# Si el nivel define fichas_n, se limita el reparto a esa cantidad (par).
func _preparar_reparto() -> void:
	_fichas_por_capa.clear()
	var total := 0

	for capa in range(1, _capas_nivel + 1):
		var capacidad := _capacidad_capa(capa)
		_fichas_por_capa.append(capacidad)
		total += capacidad

	# Las parejas exigen un total par. Si la suma de capacidades es impar,
	# se deja una celda vacía en la capa inferior (la menos visible).
	if total % 2 != 0:
		_fichas_por_capa[_capas_nivel - 1] -= 1
		total -= 1

	var objetivo := total
	if _fichas_n_nivel > 0:
		objetivo = mini(_fichas_n_nivel, total)
	if objetivo % 2 != 0:
		objetivo -= 1
	objetivo = maxi(objetivo, 0)

	# Quita fichas desde las capas inferiores hasta alcanzar fichas_n.
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

# Crea las parejas necesarias para llenar las grillas y las reparte entre capas.
# Cada capa elige celdas distintas al azar de su red hexagonal recortada.
func _generar_fichas() -> void:
	if _tipos_nivel.is_empty():
		push_error("El nivel %d no tiene tipos de ficha configurados." % nivel_actual)
		return

	var tipos: Array[int] = []

	# Cada pareja se agrega dos veces para que siempre haya match.
	for _i in range(_total_pares):
		var tipo: int = _tipos_nivel[randi() % _tipos_nivel.size()]
		tipos.append(tipo)
		tipos.append(tipo)

	# El orden aleatorio evita que las parejas queden juntas por capa.
	tipos.shuffle()

	var indice_tipo: int = 0

	for capa in range(1, _capas_nivel + 1):
		var celdas := _generar_celdas(capa)

		# Se eligen celdas distintas para evitar dos fichas en la misma celda.
		celdas.shuffle()

		var cantidad: int = _fichas_por_capa[capa - 1]
		cantidad = mini(cantidad, celdas.size())

		for i in range(cantidad):
			if indice_tipo >= tipos.size():
				break
			_crear_ficha(tipos[indice_tipo], capa, celdas[i])
			indice_tipo += 1

# Instancia una ficha, le asigna la textura de su tipo y la coloca en el mundo.
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
	# Posición inicial: X/Z finales, Y por encima de todo para la caída.
	var pos_final := _posicion_mundo(celda, capa)
	ficha.position = Vector3(pos_final.x, ALTURA_CAIDA_INICIAL, pos_final.z)
	_fichas_tablero.append(ficha)

# Convierte una celda axial (q, r) y una capa a coordenadas 3D. Las capas
# pares suman el desplazamiento de intercalado: su red cae en los huecos
# triangulares de la capa superior y deja el epicentro vacío. Además se aplica
# el centrado de capa (_patron_centro) para que patrones explícitos queden
# centrados en el tablero sin desplazarse de la pantalla.
func _posicion_mundo(celda: Vector2i, capa: int) -> Vector3:
	var centrado := Vector2.ZERO
	if capa - 1 < _patron_centro.size():
		centrado = _patron_centro[capa - 1]
	var plano := (_axial_a_plano(celda) + _desplazamiento_capa(capa) + centrado) * SEPARACION_FICHAS
	return Vector3(
		CENTRO_TABLERO.x + plano.x,
		_y_para_capa(capa),
		CENTRO_TABLERO.z + plano.y
	)

# Altura de la cara superior de cada capa. La capa 1 es la superior; la capa
# inferior (última del nivel) se apoya sobre el piso.
func _y_para_capa(capa: int) -> float:
	return ALTURA_PISO \
		+ GROSOR_FICHA \
		+ float(_capas_nivel - capa) * SEPARACION_CAPAS

# Convierte coordenadas axiales de la red hexagonal a un punto del plano XZ.
# La unidad es un diámetro de ficha.
func _axial_a_plano(celda: Vector2i) -> Vector2:
	return Vector2(
		float(celda.x) + float(celda.y) * 0.5,
		float(celda.y) * SQRT3 * 0.5
	)

# ============================================================================
#  PATRÓN DE DISTRIBUCIÓN DE FICHAS
# ----------------------------------------------------------------------------
#  Define qué celdas axiales (q,r) existen en cada capa y el desplazamiento
#  de la red por capa para que las capas se intercalen (una ficha superior
#  tapa parcialmente a las inferiores sin coincidir centros).
#
#  Formatos soportados en niveles.json -> "patron":
#   - "circulos" (por defecto) o {"tipo":"circulos","radio":2.1}
#       Fórmula: grilla hexagonal recortada a un círculo de radio R (en
#       diámetros). Capas impares centradas, pares desplazadas al hueco
#       triangular. Simple de ajustar cambiando el radio.
#   - {"tipo":"celdas","celdas_impar":[[q,r],...],"celdas_par":[[q,r],...],
#      "offset_impar":[x,y],"offset_par":[x,y]}
#       Arrays explícitos de celdas por paridad de capa: forma más directa y
#       general de "dibujar" mapas/disposiciones arbitrarias.
#
#  Para nuevos patrones basta agregar un tipo y su generador de celdas/offset.
# ============================================================================
func _parsear_celdas_patron(datos: Variant) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	if not (datos is Array):
		return celdas
	for item in datos:
		if item is Array and item.size() >= 2:
			celdas.append(Vector2i(int(item[0]), int(item[1])))
		elif item is Dictionary:
			celdas.append(Vector2i(int(item.get("q", 0)), int(item.get("r", 0))))
	return celdas

# Desplazamiento de la red para la capa según el patrón activo.
func _desplazamiento_capa(capa: int) -> Vector2:
	match _patron_tipo:
		"circulos":
			return Vector2.ZERO if capa % 2 == 1 else DESPLAZAMIENTO_INTERCALADO
		"celdas", "manual":
			return _patron_offset_impar if capa % 2 == 1 else _patron_offset_par
		_:
			return Vector2.ZERO if capa % 2 == 1 else DESPLAZAMIENTO_INTERCALADO

# Celdas válidas de la capa según el patrón activo.
func _generar_celdas(capa: int) -> Array[Vector2i]:
	match _patron_tipo:
		"circulos":
			return _celdas_circulos(capa)
		"celdas", "manual":
			var base := _patron_celdas_impar if capa % 2 == 1 else _patron_celdas_par
			return base.duplicate()
		_:
			return _celdas_circulos(capa)

# Patrón "circulos": grilla hexagonal recortada a un radio circular.
func _celdas_circulos(capa: int) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	var desplazamiento := _desplazamiento_capa(capa)
	var rango := ceili(_patron_radio) + 2
	for r in range(-rango, rango + 1):
		for q in range(-rango, rango + 1):
			var celda := Vector2i(q, r)
			var plano := _axial_a_plano(celda) + desplazamiento
			if plano.length() <= _patron_radio + 0.0001:
				celdas.append(celda)
	return celdas

# Capacidad total de una capa según el patrón activo.
func _capacidad_capa(capa: int) -> int:
	return _generar_celdas(capa).size()

# Anima la entrada de todas las fichas: caen desde ALTURA_CAIDA_INICIAL hasta
# su posición final. Las capas inferiores (número de capa mayor) empiezan a
# caer primero, y las superiores se van "enterrando" sobre ellas al terminar.
# Las fichas caen una por una con un pequeño intervalo entre inicio y otro.
func _animar_entrada_fichas() -> void:
	_animando_entrada = true
	_pendientes_entrada = 0

	# Lista ordenada: capas inferiores primero, aleatorio dentro de cada capa.
	var todas_fichas: Array = _fichas_tablero.duplicate()
	todas_fichas.sort_custom(Callable(self, "_ordenar_entrada_ficha"))
	randomize()

	var delay_actual: float = 0.0
	for ficha in todas_fichas:
		var pos_final := _posicion_mundo(ficha.celda, ficha.capa)
		var tween: Tween = ficha.create_tween()
		tween.tween_interval(delay_actual)
		tween.tween_property(ficha, "position:y", pos_final.y, DURACION_CAIDA) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(_on_entrada_ficha_terminada)
		_pendientes_entrada += 1
		delay_actual += ESPACIO_ENTRE_FICHAS

# Ordena fichas por capa descendente (inferiores primero).
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
		_actualizar_visibilidad()

# ============================================================================
#  VISIBILIDAD (OVERLAP CHECK)
# ============================================================================
# Recalcula qué fichas están libres. Se llama después de generar el tablero
# y después de retirar una ficha, porque al eliminar una capa superior las
# fichas de abajo pueden quedar destapadas.
func _actualizar_visibilidad() -> void:
	for ficha in _fichas_tablero:
		ficha.libre = _esta_libre(ficha)
		_aplicar_estado_visual(ficha)

# Una ficha está libre si ninguna ficha de una capa superior se superpone
# a su huella circular en el plano XZ.
func _esta_libre(ficha: FichaTablero) -> bool:
	for otra in _fichas_tablero:
		if otra == ficha:
			continue
		# Capa 1 es la más alta. Sólo las capas con número menor tapan.
		if otra.capa >= ficha.capa:
			continue
		if _se_superponen(ficha, otra):
			return false
	return true

# Comprueba si dos fichas redondas se superponen. Al ser círculos del mismo
# diámetro, basta comparar la distancia entre sus centros contra el diámetro.
func _se_superponen(a: FichaTablero, b: FichaTablero) -> bool:
	var dx := a.global_position.x - b.global_position.x
	var dz := a.global_position.z - b.global_position.z
	const EPSILON: float = 0.0001
	return sqrt(dx * dx + dz * dz) < DIAMETRO_FICHA - EPSILON

# Feedback visual: las fichas tapadas se muestran oscurecidas.
func _aplicar_estado_visual(ficha: FichaTablero) -> void:
	if ficha.material == null:
		return

	# Las fichas libres conservan su brillo original.
	var brillo := 1.0
	if not ficha.libre:
		# Las bloqueadas se oscurecen según la capa a la que pertenecen.
		var indice := clampi(ficha.capa - 1, 0, OSCURIDAD_BASE_CAPAS.size() - 1)
		brillo = 1.0 - OSCURIDAD_BASE_CAPAS[indice]

	ficha.material.set_shader_parameter("brillo", brillo)

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
		# En móvil se usan eventos táctiles. En escritorio, el mouse.
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

	# La ficha debe estar totalmente libre para poder tocarse.
	if not ficha.libre:
		return

	_seleccionar_ficha(ficha)

# Lanza un rayo desde la cámara y devuelve la ficha más cercana que golpea.
# Como la cámara mira hacia abajo, la ficha más cercana es la de capa superior.
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

	# Si esa cara ya espera en la barra (combo activo o ficha solitaria),
	# la ficha viaja a su coincidencia y se (re)abre la ventana de 2 segundos.
	var slot_match := _buscar_slot_por_tipo(tipo)

	if slot_match != -1:
		if _combo_activo and _combo_slot == slot_match:
			# Misma cara del combo activo: solo se suma al mismo slot y se reinicia el timer.
			_combo_contador += 1
		else:
			# Se cambia el foco a este slot: se resuelve el combo activo previo (si lo hay)
			# y se activa la acumulación en el slot coincidente.
			if _combo_activo:
				_romper_combo()
			_combo_activo = true
			_combo_tipo = tipo
			_combo_slot = slot_match
			_combo_contador = _barra_conteo[slot_match] + 1
		_barra_conteo[_combo_slot] = _combo_contador
	else:
		# Cara nueva en la barra: se resuelve el combo activo y se ocupa un slot libre.
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

	# Marcar la ficha en la barra. Se registra siempre el vuelo para no resolver
	# el combo mientras una coincidencia está en animación; el icono solo se
	# oculta para la primera ficha que ocupa el slot.
	_barra_tipos[_combo_slot] = tipo
	_slots_en_vuelo.append(_combo_slot)

	# Cada coincidencia acumulada muestra +1, +2, +3... al aterrizar en el slot.
	var puntos_ganados := 0
	if _combo_contador >= 2:
		puntos_ganados = _combo_contador - 1

	# La ficha 3D seleccionada vuela hasta la barra. Se quita del tablero de
	# inmediato para que no pueda volver a seleccionarse mientras está en el aire.
	_animar_ficha_a_barra(ficha, _combo_slot, puntos_ganados)

	if main_audio:
		main_audio.play_select()

	_fichas_tablero.erase(ficha)
	ficha.libre = false
	if ficha.cuerpo:
		ficha.cuerpo.collision_layer = 0
	_fichas_en_vuelo.append(ficha)

	# Al quitar esta ficha pueden quedar libres fichas de capas inferiores.
	_actualizar_visibilidad()

# Crea el nodo Timer que gestiona la ventana de 2 segundos del combo.
func _crear_timer_combo() -> void:
	_timer_combo = Timer.new()
	_timer_combo.name = "TimerCombo"
	_timer_combo.one_shot = true
	_timer_combo.wait_time = TIEMPO_COMBO
	_timer_combo.timeout.connect(_on_timer_combo_timeout)
	add_child(_timer_combo)

# Detiene el timer del combo y resuelve el slot activo.
# - 2+ acumuladas: desaparecen al cerrarse la ventana de 2s sin nueva coincidencia
#   o al seleccionar una ficha de otra cara.
# - 1 sola (solitaria): se queda en su slot.
func _romper_combo() -> void:
	if not _combo_activo:
		return
	if _timer_combo:
		_timer_combo.stop()

	var hay_coincidencias := _combo_contador >= 2

	if hay_coincidencias:
		# 2+ acumuladas: el slot desaparece (ventana cerrada o ficha distinta).
		for ficha in _fichas_en_vuelo:
			if is_instance_valid(ficha):
				ficha.queue_free()
		_fichas_en_vuelo.clear()
		while _slots_en_vuelo.has(_combo_slot):
			_slots_en_vuelo.erase(_combo_slot)
		var combo_acumulado: int = int(_combo_contador * (_combo_contador - 1) / 2)
		_puntaje_nivel += combo_acumulado
		if ui_puntaje:
			ui_puntaje.establecer_puntaje(_puntaje_nivel)
		# paycombo
		_mostrar_puntos_flotantes_en_slot(_combo_slot, combo_acumulado, false)
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
				_disparar_smoke_puff(interseccion)
		# Vaciar el slot del combo en la barra.
		if _combo_slot >= 0 and _combo_slot < _barra_tipos.size():
			_barra_tipos[_combo_slot] = 0
			_barra_conteo[_combo_slot] = 0
			_barra_icono_oculto[_combo_slot] = false
	else:
		# Solitaria (1): se queda en su slot. No destruir fichas en vuelo para
		# que puedan aterrizar y mostrarse.
		_fichas_en_vuelo.clear()

	_actualizar_barra_ui()
	_combo_activo = false
	_combo_tipo = 0
	_combo_slot = -1
	_combo_contador = 0

	# Victoria: tablero vacío y barra vacía.
	if _fichas_tablero.is_empty() and _barra_esta_vacia():
		_finalizar_partida(true)

# Se dispara cuando se agotan los 2 segundos de ventana del combo.
func _on_timer_combo_timeout() -> void:
	# Si aún hay una ficha volando hacia el slot activo, la ventana se abrirá
	# al aterrizar; no se resuelve todavía.
	if _combo_activo and _slots_en_vuelo.has(_combo_slot):
		return
	_romper_combo()

# Devuelve true si no hay ningún tipo en la barra.
func _barra_esta_vacia() -> bool:
	for t in _barra_tipos:
		if t != 0:
			return false
	return true

# Devuelve el índice del primer slot vacío de la barra, o -1 si la barra está llena.
func _primer_slot_libre() -> int:
	for i in range(_barra_tipos.size()):
		if _barra_tipos[i] == 0:
			return i
	return -1

# Devuelve el índice del slot de la barra que ya lleva este tipo, o -1 si ninguno lo tiene.
func _buscar_slot_por_tipo(tipo: int) -> int:
	if tipo == 0:
		return -1
	for i in range(_barra_tipos.size()):
		if _barra_tipos[i] == tipo:
			return i
	return -1

# Inicia (o reinicia) la ventana de tiempo del combo.
func _iniciar_timer_combo() -> void:
	if _timer_combo:
		_timer_combo.stop()
		_timer_combo.start()

# ============================================================================
#  BARRA INFERIOR ("SCRABBLE BAR")
# ============================================================================
# Crea por código la barra de 5 espacios en la parte inferior de la pantalla.
# Se renderiza en un quad 3D apoyado en el piso para que las fichas queden
# siempre por encima de ella.
func _crear_barra_ui() -> void:
	# Crea la infraestructura 3D de la barra una vez y (re)construye los slots
	# según la cantidad configurada para el nivel actual.
	var entorno_ficha := _crear_entorno_ficha()
	var textura_inicial: Texture2D = null
	if not _texturas.is_empty():
		textura_inicial = _texturas[0]

	if _barra_ui == null or not is_instance_valid(_barra_ui):
		_barra_ui = Control.new()
		_barra_ui.name = "BarraRecoleccion"
		_barra_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

		# Contenedor horizontal centrado para los espacios de la barra.
		_barra_slots_box = HBoxContainer.new()
		_barra_slots_box.name = "Slots"
		_barra_slots_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_barra_slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_barra_slots_box.add_theme_constant_override("separation", 12)
		_barra_slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barra_ui.add_child(_barra_slots_box)

		# La barra se dibuja en un quad 3D sobre el piso, alineado con el
		# rectángulo inferior de la pantalla.
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
		# Infraestructura existente: solo se reconstruyen los slots si cambia la cantidad.
		_barra_slots_box = _barra_ui.get_node_or_null("Slots") as HBoxContainer

	# Reconstruir slots para el nivel actual.
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

		_barra_slots_box.add_child(slot)
		_slots.append(slot)
		_slots_texturas.append(icono)
		_slots_viewports.append(viewport)
		_slots_fichas.append(ficha)
		_slots_materiales.append(material_ficha)

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

# Registra la llegada visual de una ficha al slot del combo. Ya no se resuelven
# parejas aquí: el combo se rompe por tiempo agotado o por ficha distinta.
func _agregar_a_barra(tipo: int) -> void:
	if _juego_terminado:
		return

	if _combo_slot >= 0 and _combo_slot < _barra_tipos.size():
		_barra_tipos[_combo_slot] = tipo
	_actualizar_barra_ui()

	# Victoria: tablero vacío y barra vacía (último combo roto sin fichas
	# pendientes).
	if _fichas_tablero.is_empty() and _barra_esta_vacia():
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

func _disparar_smoke_puff(posicion: Vector3) -> void:
	if camara == null or _capa_efectos == null:
		return
	var fx := SMOKE_PUFF_2D.instantiate() as CrispFx2D
	if fx == null:
		return
	fx.autoplay = false
	fx.fx_scale = ESCALA_SMOKE_PUFF
	_capa_efectos.add_child(fx)
	fx.global_position = camara.unproject_position(posicion)
	# paycombo
	fx.play()

# Muestra un texto flotante sobre el slot indicado de la barra.
# con_signo=true -> "+1, +2..."; con_signo=false -> total acumulado (ej. "3").
func _mostrar_puntos_flotantes_en_slot(indice_slot: int, puntos: int, con_signo: bool = true) -> void:
	if _capa_efectos == null or _barra_ui == null or indice_slot < 0 or indice_slot >= _slots.size():
		return
	var fx := PUNTOS_FLOTANTES_ESCENA.instantiate() as Control
	if fx == null:
		return
	var etiqueta := fx.get_node_or_null("Label") as Label
	if etiqueta:
		etiqueta.text = ("+%d" % puntos) if con_signo else str(puntos)
		etiqueta.reset_size()
	_capa_efectos.add_child(fx)

	# El slot vive dentro del viewport de la barra: se traduce su rectángulo al
	# área inferior de la pantalla donde se proyecta esa barra.
	var rect_slot := _slots[indice_slot].get_global_rect()
	var pantalla := get_viewport().get_visible_rect().size
	var centro := Vector2(
		rect_slot.get_center().x,
		pantalla.y - ALTO_BARRA + rect_slot.position.y
	)
	fx.global_position = centro
	if etiqueta:
		etiqueta.position = Vector2(-etiqueta.size.x * 0.5, -etiqueta.size.y)

	var tween := fx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "position:y", fx.position.y - 90.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(fx.queue_free)

# Anima la ficha 3D seleccionada desde su posición en el tablero hasta el
# centro del slot correspondiente de la barra. La ficha se lanza en arco y
# gira como una moneda al aire mientras se encoge para encajar en el espacio;
# al terminar el vuelo se libera, se muestra el icono del slot y, si corresponde,
# se disparan los puntos de la coincidencia.
func _animar_ficha_a_barra(ficha: FichaTablero, indice_slot: int, puntos_ganados: int = 0) -> void:
	if _slots.is_empty() or camara == null:
		ficha.queue_free()
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
	var plano := Plane(Vector3.UP, ficha.global_position.y)
	var interseccion: Variant = plano.intersects_ray(
		camara.project_ray_origin(centro_slot),
		camara.project_ray_normal(centro_slot)
	)
	if interseccion == null:
		ficha.queue_free()
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
	var origen: Vector3 = ficha.global_position
	var distancia := origen.distance_to(destino)
	var altura_arco := clampf(distancia * 0.25, 0.05, 0.18)

	# El vuelo parte desde lo alto del salto inicial.
	var origen_vuelo := origen + Vector3(0.0, ALTURA_SALTO_SELECCION, 0.0)
	var mover := func(t: float) -> void:
		var pos := origen_vuelo.lerp(destino, t)
		pos.y += sin(t * PI) * altura_arco
		ficha.global_position = pos

	var tween := ficha.create_tween()
	# 1) Salto vertical en el sitio, como preparación del lanzamiento.
	tween.tween_property(ficha, "global_position:y", origen_vuelo.y, DURACION_SALTO) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	# 2) Vuelo hacia la barra; comienza al terminar el salto.
	tween.chain().tween_method(mover, 0.0, 1.0, DURACION_VUELO) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	# Dos vueltas completas sobre el eje X: termina de nuevo con la cara
	# hacia arriba, como una moneda que cae de canto y vuelve a su posición.
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
		# La ficha aterrizó: revelar su icono en el slot.
		var idx := _slots_en_vuelo.find(indice_slot)
		if idx != -1:
			_slots_en_vuelo.remove_at(idx)
		if indice_slot >= 0 and indice_slot < _barra_icono_oculto.size():
			_barra_icono_oculto[indice_slot] = false
		_actualizar_barra_ui()
		# Los puntos se muestran al llegar la ficha a su destino.
		if puntos_ganados > 0:
			_mostrar_puntos_flotantes_en_slot(indice_slot, puntos_ganados)
		# Al mostrarse en la barra, se (re)abre la ventana de 2 segundos del combo activo.
		if _combo_activo and _combo_slot == indice_slot:
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
