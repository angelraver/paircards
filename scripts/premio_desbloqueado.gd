extends Control

const CARPETA_PREMIOS = "res://assets/images/prizes/"
const ESCENA_SELECCION_NIVELES = "res://scenes/seleccion_niveles.tscn"

@onready var panel_premio: Control = $PanelPremio # Asumo que es tipo Control o derivado
@onready var label_titulo: Label = $PanelPremio/Titulo
@onready var label_nombre: Label = $PanelPremio/Nombre
@onready var imagen_juguete: TextureRect = $PanelPremio/ImagenJuguete
@onready var boton_pantalla: Button = $BotonPantalla


# --- ALMACENAMIENTO DE TRANSFORMACIONES ORIGINALES (Blindaje) ---
# Panel Padre
var scale_orig_panel: Vector2
# Hijos
var scale_orig_juguete: Vector2
var scale_orig_titulo: Vector2
var scale_orig_instruccion: Vector2

func _ready() -> void:
	audio_manager.play_prize()

	var nombre_premio = save_manager.premio_recien_desbloqueado
	var ruta_imagen = CARPETA_PREMIOS + nombre_premio + ".png"

	if ResourceLoader.exists(ruta_imagen):
		imagen_juguete.texture = load(ruta_imagen)

	label_titulo.text = game_manager.obtener_texto("nuevo_premio")
	label_nombre.text = nombre_premio.to_upper()

	# Panel Padre
	panel_premio.pivot_offset = panel_premio.size / 2
	scale_orig_panel = panel_premio.scale

	# Hijo 1: Título
	label_titulo.pivot_offset = label_titulo.size / 2
	scale_orig_titulo = label_titulo.scale

	# Hijo 2: Imagen Juguete
	imagen_juguete.pivot_offset = imagen_juguete.size / 2
	scale_orig_juguete = imagen_juguete.scale

	# Hijo 3: Instrucción
	label_nombre.pivot_offset = label_nombre.size / 2
	scale_orig_instruccion = label_nombre.scale

	# --- 2. ESTADO INICIAL PARA LA ANIMACIÓN ---
	# Panel Padre: Comienza al 50% de SU escala original
	panel_premio.scale = scale_orig_panel * 0.5
	
	# Hijos: Comienzan al 0% (invisibles)
	label_titulo.scale = Vector2.ZERO
	imagen_juguete.scale = Vector2.ZERO
	label_nombre.scale = Vector2.ZERO


	# --- LÓGICA DE BOTÓN EXISTENTE ---
	if boton_pantalla:
		boton_pantalla.pressed.connect(_on_pantalla_pressed)


	# --- 3. DISPARAR SECUENCIA DE ANIMACIÓN ---
	ejecutar_secuencia_entrada()


# --- NUEVA FUNCIÓN DE SECUENCIA DE ANIMACIÓN ---
func ejecutar_secuencia_entrada() -> void:
	# --- FASE 1: PANEL PREMIO (50% -> 110% -> 100%) ---
	var tween_panel = create_tween()
	panel_premio.visible = true # Asegurar que es visible

	# Crece del 50% inicial al 110% de su escala original
	tween_panel.tween_property(panel_premio, "scale", scale_orig_panel * 1.1, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Rebota y se asienta exactamente en su escala original (100%)
	tween_panel.tween_property(panel_premio, "scale", scale_orig_panel, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# --- ESPERA A QUE TERMINE EL PANEL ---
	await tween_panel.finished # Espera a que la Fase 1 complete


	# --- FASE 2: HIJOS EN CASCADA (0% -> 110% -> 100%) ---
	# Título -> Juguete -> Instrucción
	const DELAY_ENTRE_HIJOS = 0.15 # Tiempo de espera entre apariciones

	# 1. Aparece el Título
	animar_pop_control(label_titulo, scale_orig_titulo)
	await get_tree().create_timer(DELAY_ENTRE_HIJOS).timeout # Pequeño delay

	# 2. Aparece el Juguete
	animar_pop_control(imagen_juguete, scale_orig_juguete)
	await get_tree().create_timer(DELAY_ENTRE_HIJOS).timeout # Pequeño delay

	# 3. Aparece la Instrucción
	animar_pop_control(label_nombre, scale_orig_instruccion)


# --- FUNCIÓN HELPER DE ANIMACIÓN "POP" (Reutilizada de Main) ---
# Realiza el efecto 0% -> 110% -> 100% para un nodo control restableciendo su posición
func animar_pop_control(node: Control, scale_objetivo: Vector2) -> void:
	node.scale = Vector2.ZERO
	node.visible = true # Asegurar visible

	var tween = create_tween()
	
	# Paso A: Crece del 0% al 110% de su escala guardada
	tween.tween_property(node, "scale", scale_objetivo * 1.1, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Paso B: Se asienta exactamente en su escala guardada (100%)
	tween.tween_property(node, "scale", scale_objetivo, 0.10)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _on_pantalla_pressed() -> void:
	audio_manager.play_ok1()
	# Consumir la alerta para que no se vuelva a mostrar
	save_manager.premio_recien_desbloqueado = ""
	# Ir a la selección de niveles del juego actual
	get_tree().change_scene_to_file(ESCENA_SELECCION_NIVELES)
