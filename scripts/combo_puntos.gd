extends RefCounted
class_name ComboPuntos

const BASE_PUNTOS_FICHA: int = 100
const VENTANA_COMBO_SEG: float = 2.0

const TABLA_COMBOS: Array[Dictionary] = [
	{ "combo": 2, "multiplicador": 1.0, "etiqueta": "PAR" },
	{ "combo": 3, "multiplicador": 1.3, "etiqueta": "TRÍO" },
	{ "combo": 4, "multiplicador": 1.7, "etiqueta": "CUARTETO" },
	{ "combo": 5, "multiplicador": 2.2, "etiqueta": "QUINTETO" },
	{ "combo": 6, "multiplicador": 2.8, "etiqueta": "SEXTETO" },
	{ "combo": 7, "multiplicador": 3.5, "etiqueta": "SÉPTIMO" },
	{ "combo": 8, "multiplicador": 4.4, "etiqueta": "OCTETO" },
	{ "combo": 9, "multiplicador": 5.6, "etiqueta": "NOVENO" },
	{ "combo": 10, "multiplicador": 7.2, "etiqueta": "ASTRAL +10" },
]

static func obtener_config_combo(cantidad_fichas: int) -> Dictionary:
	var nivel := clampi(cantidad_fichas, 2, 10)
	return TABLA_COMBOS[nivel - 2]

static func calcular_puntos_combo(cantidad_fichas: int) -> Dictionary:
	var config := obtener_config_combo(cantidad_fichas)
	var fichas_validas := maxi(2, cantidad_fichas)
	var puntos := int(round(float(fichas_validas) * float(BASE_PUNTOS_FICHA) * float(config["multiplicador"])))
	return {
		"puntos": puntos,
		"multiplicador": float(config["multiplicador"]),
		"etiqueta": str(config["etiqueta"]),
	}

static func contador_tras_inactividad(segundos: float, contador_actual: int) -> int:
	return 0 if segundos > VENTANA_COMBO_SEG else contador_actual

static func verificar_reglas() -> void:
	assert(int(calcular_puntos_combo(2)["puntos"]) == 200)
	assert(int(calcular_puntos_combo(10)["puntos"]) == 7200)
	assert(contador_tras_inactividad(2.01, 5) == 0)
	assert(contador_tras_inactividad(2.0, 5) == 5)
