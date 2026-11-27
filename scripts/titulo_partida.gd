class_name TituloPartida
extends RefCounted

const ESPERA_TITULO: float = 3.0
const DURACION_FADE: float = 1.0
const TAMANO_TITULO: int = 64
const TAMANO_MENSAJE: int = 72

var _label: Label = null
var _tween: Tween = null

func configurar(label: Label) -> void:
	_label = label
	if _label == null:
		return
	_label.visible = false
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func actualizar_nivel(nivel: int) -> void:
	mostrar_nivel(nivel, save_manager.juego_actual_seleccionado)

func mostrar_nivel(nivel: int, id_juego: String) -> void:
	if _label == null:
		return
	_detener_tween()
	_label.modulate.a = 1.0
	var titulo_str: String = game_manager.obtener_titulo_nivel(str(nivel), id_juego)
	_label.text = "Nivel %d\n%s" % [nivel, titulo_str]
	_label.add_theme_font_size_override("font_size", TAMANO_TITULO)
	_label.visible = true
	_tween = _label.create_tween()
	_tween.tween_interval(ESPERA_TITULO)
	_tween.tween_property(_label, "modulate:a", 0.0, DURACION_FADE)
	_tween.tween_callback(_ocultar)

func mostrar_mensaje(texto: String) -> void:
	if _label == null:
		return
	_detener_tween()
	_label.modulate.a = 1.0
	_label.text = texto
	_label.add_theme_font_size_override("font_size", TAMANO_MENSAJE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.visible = true

func ocultar() -> void:
	_detener_tween()
	if _label != null:
		_label.visible = false

func _detener_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

func _ocultar() -> void:
	_tween = null
	if _label != null:
		_label.visible = false
