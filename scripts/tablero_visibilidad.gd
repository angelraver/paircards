class_name TableroVisibilidad
extends RefCounted

var _diametro_ficha: float = 0.132
var _oscuridad_base_capas: Array[float] = []

func configurar(p_diametro_ficha: float, p_oscuridad_base_capas: Array[float]) -> void:
	_diametro_ficha = p_diametro_ficha
	_oscuridad_base_capas = p_oscuridad_base_capas

func actualizar(fichas: Array[FichaTablero]) -> void:
	for ficha in fichas:
		ficha.libre = esta_libre(ficha, fichas)
		_aplicar_estado_visual(ficha)

func esta_libre(ficha: FichaTablero, fichas: Array[FichaTablero]) -> bool:
	for otra in fichas:
		if otra == ficha:
			continue
		if otra.capa >= ficha.capa:
			continue
		if se_superponen(ficha, otra):
			return false
	return true

func se_superponen(a: FichaTablero, b: FichaTablero) -> bool:
	var dx := a.global_position.x - b.global_position.x
	var dz := a.global_position.z - b.global_position.z
	const EPSILON: float = 0.0001
	return sqrt(dx * dx + dz * dz) < _diametro_ficha - EPSILON

func _aplicar_estado_visual(ficha: FichaTablero) -> void:
	if ficha.material == null:
		return

	var brillo := 1.0
	if not ficha.libre:
		var indice := clampi(ficha.capa - 1, 0, _oscuridad_base_capas.size() - 1)
		brillo = 1.0 - _oscuridad_base_capas[indice]

	ficha.material.set_shader_parameter("brillo", brillo)
