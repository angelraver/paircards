class_name EfectosPartida
extends Node

const SMOKE_PUFF_2D: PackedScene = preload(
	"res://crisp_juice_fx/fx2d/elements/smoke_puff_2d.tscn"
)
const PUNTOS_FLOTANTES_ESCENA: PackedScene = preload("res://scenes/puntos_flotantes.tscn")
const ESCALA_SMOKE_PUFF: float = 1.0
const ALTO_BARRA: float = 200.0

var _camara: Camera3D = null
var _slots: Array[Panel] = []
var _capa_efectos: Control = null

func configurar(ui: CanvasLayer, camara: Camera3D, slots: Array[Panel]) -> void:
	_camara = camara
	_slots = slots
	if ui == null:
		return

	_capa_efectos = Control.new()
	_capa_efectos.name = "CapaEfectos"
	_capa_efectos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa_efectos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_capa_efectos)
	ui.move_child(_capa_efectos, 1)

func actualizar_slots(slots: Array[Panel]) -> void:
	_slots = slots

func limpiar() -> void:
	if _capa_efectos == null:
		return
	for hijo in _capa_efectos.get_children():
		_capa_efectos.remove_child(hijo)
		hijo.queue_free()

func disparar_smoke_puff(posicion: Vector3) -> void:
	if _camara == null or _capa_efectos == null:
		return
	var fx := SMOKE_PUFF_2D.instantiate() as CrispFx2D
	if fx == null:
		return
	fx.autoplay = false
	fx.fx_scale = ESCALA_SMOKE_PUFF
	_capa_efectos.add_child(fx)
	fx.global_position = _camara.unproject_position(posicion)
	fx.play()

func mostrar_puntos_flotantes_en_slot(
	indice_slot: int,
	puntos: int,
	con_signo: bool = true,
	texto_etiqueta: String = ""
) -> void:
	if _capa_efectos == null or indice_slot < 0 or indice_slot >= _slots.size():
		return
	var fx := PUNTOS_FLOTANTES_ESCENA.instantiate() as Control
	if fx == null:
		return
	var etiqueta := fx.get_node_or_null("Label") as Label
	if etiqueta:
		var texto := ("+%d" % puntos) if con_signo else str(puntos)
		if texto_etiqueta != "":
			texto = "%s\n%s" % [texto_etiqueta, texto]
		etiqueta.text = texto
		etiqueta.reset_size()
	_capa_efectos.add_child(fx)

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
