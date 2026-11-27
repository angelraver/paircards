class_name TableroGeometria
extends RefCounted

const RADIO_MAX_CAPA: float = 2.1
const DESPLAZAMIENTO_INTERCALADO := Vector2(0.5, 0.28867513459481287)
const DIAMETRO_FICHA: float = 0.132
const SEPARACION_FICHAS: float = DIAMETRO_FICHA
const SEPARACION_CAPAS: float = 0.026
const GROSOR_FICHA: float = 0.022
const ALTURA_PISO: float = -0.04
const SQRT3: float = 1.7320508075688772
const CENTRO_TABLERO := Vector3(0.0, 0.0, 0.16)

var _capas_nivel: int = 1
var _patron_tipo: String = "circulos"
var _patron_radio: float = RADIO_MAX_CAPA
var _patron_offset_impar: Vector2 = Vector2.ZERO
var _patron_offset_par: Vector2 = DESPLAZAMIENTO_INTERCALADO
var _patron_celdas_impar: Array[Vector2i] = []
var _patron_celdas_par: Array[Vector2i] = []
var _patron_centro: Array[Vector2] = []

func configurar_nivel(p_capas_nivel: int, p_patron_cfg: Variant) -> void:
	_capas_nivel = maxi(p_capas_nivel, 1)
	_patron_tipo = "circulos"
	_patron_radio = RADIO_MAX_CAPA
	_patron_offset_impar = Vector2.ZERO
	_patron_offset_par = DESPLAZAMIENTO_INTERCALADO
	_patron_celdas_impar.clear()
	_patron_celdas_par.clear()

	if p_patron_cfg is String:
		_patron_tipo = str(p_patron_cfg)
	elif p_patron_cfg is Dictionary:
		_patron_tipo = str(p_patron_cfg.get("tipo", "circulos"))
		_patron_radio = float(p_patron_cfg.get("radio", RADIO_MAX_CAPA))
		var off_i: Variant = p_patron_cfg.get("offset_impar", null)
		if off_i is Array and off_i.size() >= 2:
			_patron_offset_impar = Vector2(float(off_i[0]), float(off_i[1]))
		var off_p: Variant = p_patron_cfg.get("offset_par", null)
		if off_p is Array and off_p.size() >= 2:
			_patron_offset_par = Vector2(float(off_p[0]), float(off_p[1]))
		_patron_celdas_impar = _parsear_celdas_patron(p_patron_cfg.get("celdas_impar", []))
		_patron_celdas_par = _parsear_celdas_patron(p_patron_cfg.get("celdas_par", p_patron_cfg.get("celdas", [])))

	_patron_centro.clear()
	for capa in range(1, _capas_nivel + 1):
		var celdas := generar_celdas(capa)
		if celdas.is_empty():
			_patron_centro.append(Vector2.ZERO)
			continue
		var centro := Vector2.ZERO
		for celda in celdas:
			centro += _axial_a_plano(celda)
		centro /= float(celdas.size())
		_patron_centro.append(-centro)

func posicion_mundo(celda: Vector2i, capa: int) -> Vector3:
	var centrado := Vector2.ZERO
	if capa - 1 < _patron_centro.size():
		centrado = _patron_centro[capa - 1]
	var plano := (_axial_a_plano(celda) + _desplazamiento_capa(capa) + centrado) * SEPARACION_FICHAS
	return Vector3(
		CENTRO_TABLERO.x + plano.x,
		y_para_capa(capa),
		CENTRO_TABLERO.z + plano.y
	)

func y_para_capa(capa: int) -> float:
	return ALTURA_PISO \
		+ GROSOR_FICHA \
		+ float(_capas_nivel - capa) * SEPARACION_CAPAS

func generar_celdas(capa: int) -> Array[Vector2i]:
	match _patron_tipo:
		"circulos":
			return _celdas_circulos(capa)
		"celdas", "manual":
			var base := _patron_celdas_impar if capa % 2 == 1 else _patron_celdas_par
			var celdas: Array[Vector2i] = []
			celdas.append_array(base)
			return celdas
		_:
			return _celdas_circulos(capa)

func capacidad_capa(capa: int) -> int:
	return generar_celdas(capa).size()

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

func _desplazamiento_capa(capa: int) -> Vector2:
	match _patron_tipo:
		"circulos":
			return Vector2.ZERO if capa % 2 == 1 else DESPLAZAMIENTO_INTERCALADO
		"celdas", "manual":
			return _patron_offset_impar if capa % 2 == 1 else _patron_offset_par
		_:
			return Vector2.ZERO if capa % 2 == 1 else DESPLAZAMIENTO_INTERCALADO

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

func _axial_a_plano(celda: Vector2i) -> Vector2:
	return Vector2(
		float(celda.x) + float(celda.y) * 0.5,
		float(celda.y) * SQRT3 * 0.5
	)
