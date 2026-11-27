class_name LevelSequenceChunk
extends Control

const ANCHO_BASE: float = 557.0
const ALTO_BASE: float = 842.0
const NIVELES_POR_CHUNK: int = 9
const NIVELES_NETOS: int = 8
const ESCENA_SLOT: PackedScene = preload("res://scenes/slot_nivel.tscn")

signal nivel_seleccionado(numero_nivel: int)
signal level_selected(level_number: int)

@export var slot_size: float = 40.0
@export var slot_scale: float = 0.65
@export var node_normalized_positions: Array[Vector2] = [
	Vector2(0.463, 0.86),
	Vector2(0.26, 0.66),
	Vector2(0.666, 0.66),
	Vector2(0.105, 0.455),
	Vector2(0.463, 0.455),
	Vector2(0.825, 0.455),
	Vector2(0.26, 0.245),
	Vector2(0.67, 0.245),
	Vector2(0.463, 0.05),
]
@export var col_center_x: float = -1.0
@export var col_inner_offset_x: float = -1.0
@export var col_outer_offset_x: float = -1.0

@onready var contenedor_slots: Control = $ContenedorSlots
@onready var ilustracion: TextureRect = $Ilustracion

var indice_secuencia: int = -1
var factor_escala: float = 1.0
var niveles_chunk: Array[int] = []
var ocultar_nodo_inicial: bool = false

var _slots: Array[SlotNivel] = []


func _ready() -> void:
	_asegurar_slots()
	configurar(indice_secuencia, factor_escala, [], ocultar_nodo_inicial)


func configurar(indice: int, escala: float, niveles: Array[int] = [], ocultar_inicial: bool = false) -> void:
	indice_secuencia = indice
	factor_escala = maxf(escala, 0.01)

	var indice_valido: int = maxi(indice, 0)
	niveles_chunk.clear()
	niveles_chunk.append_array(niveles)
	ocultar_nodo_inicial = ocultar_inicial or indice_valido > 0

	var tamano_base: Vector2 = Vector2(ANCHO_BASE, ALTO_BASE)
	custom_minimum_size = tamano_base
	size = tamano_base
	offset_left = 0.0
	offset_top = 0.0
	offset_right = ANCHO_BASE
	offset_bottom = ALTO_BASE
	scale = Vector2.ONE * factor_escala

	ilustracion.position = Vector2.ZERO
	ilustracion.size = tamano_base
	contenedor_slots.position = Vector2.ZERO
	contenedor_slots.size = tamano_base

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ilustracion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_asegurar_slots()
	_posicionar_slots()

	if indice >= 0:
		name = "Sequence%02d" % indice


func _asegurar_slots() -> void:
	if contenedor_slots == null:
		return
	if _slots.size() == NIVELES_POR_CHUNK:
		return

	for slot in _slots:
		slot.queue_free()
	_slots.clear()

	for i in range(NIVELES_POR_CHUNK):
		var slot: SlotNivel = ESCENA_SLOT.instantiate() as SlotNivel
		if slot == null:
			continue
		contenedor_slots.add_child(slot)
		if not slot.nivel_seleccionado.is_connected(_on_slot_nivel_seleccionado):
			slot.nivel_seleccionado.connect(_on_slot_nivel_seleccionado)
		if not slot.level_selected.is_connected(_on_slot_level_selected):
			slot.level_selected.connect(_on_slot_level_selected)
		_slots.append(slot)


func _posicionar_slots() -> void:
	var rect_arte: Rect2 = ilustracion.get_rect()
	var escala_slot: float = maxf(slot_scale, 0.01)
	for i in range(_slots.size()):
		var slot: SlotNivel = _slots[i]
		var tiene_nivel: bool = i < niveles_chunk.size()
		var es_compartido: bool = i == 0 and ocultar_nodo_inicial and tiene_nivel
		var debe_mostrarse: bool = tiene_nivel and not es_compartido

		if tiene_nivel:
			slot.configurar_nivel(niveles_chunk[i])
		else:
			slot.boton_nivel.disabled = true
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.size = Vector2(slot_size, slot_size)
		slot.pivot_offset = Vector2.ZERO
		slot.scale = Vector2.ONE * escala_slot

		var normalizado: Vector2 = _posicion_normalizada(i)
		var objetivo: Vector2 = Vector2(
			rect_arte.position.x + normalizado.x * rect_arte.size.x,
			rect_arte.position.y + normalizado.y * rect_arte.size.y
		)
		var tamano_efectivo: Vector2 = slot.size * escala_slot
		slot.position = objetivo - tamano_efectivo * 0.5
		slot.visible = debe_mostrarse
		slot.z_index = 10
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE if not debe_mostrarse else Control.MOUSE_FILTER_STOP


func _posicion_normalizada(indice: int) -> Vector2:
	var posicion: Vector2 = node_normalized_positions[indice] if indice >= 0 and indice < node_normalized_positions.size() else Vector2(0.5, 0.5)

	if col_center_x < 0.0:
		return posicion

	var x: float = col_center_x
	match indice:
		1, 6:
			if col_inner_offset_x >= 0.0:
				x = col_center_x - col_inner_offset_x
		2, 7:
			if col_inner_offset_x >= 0.0:
				x = col_center_x + col_inner_offset_x
		3:
			if col_outer_offset_x >= 0.0:
				x = col_center_x - col_outer_offset_x
		5:
			if col_outer_offset_x >= 0.0:
				x = col_center_x + col_outer_offset_x
	return Vector2(x, posicion.y)


func _on_slot_nivel_seleccionado(numero_nivel: int) -> void:
	nivel_seleccionado.emit(numero_nivel)


func _on_slot_level_selected(level_number: int) -> void:
	level_selected.emit(level_number)
