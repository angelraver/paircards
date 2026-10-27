class_name FondoDinamico
extends RefCounted

## Fondo dinámico según la hora local del dispositivo.
## Franjas: 06:00-16:59 día, 17:00-19:59 tarde, 20:00-05:59 noche.
## Time.get_datetime_dict_from_system() devuelve "hour" en 0-23
## independientemente del formato AM/PM del sistema, así que la
## comparación siempre se hace en 24h (6 = 6am, 17 = 5pm, 20 = 8pm).

const RUTA_DIA: String = "res://assets/images/fondodia.webp"
const RUTA_TARDE: String = "res://assets/images/fondotarde.webp"
const RUTA_NOCHE: String = "res://assets/images/fondonoche.webp"

const HORA_DIA_INICIO: int = 6
const HORA_TARDE_INICIO: int = 17
const HORA_NOCHE_INICIO: int = 20


static func ruta_para_hora(hora: int) -> String:
	var h: int = normalizar_hora(hora)
	if h >= HORA_DIA_INICIO and h < HORA_TARDE_INICIO:
		return RUTA_DIA
	if h >= HORA_TARDE_INICIO and h < HORA_NOCHE_INICIO:
		return RUTA_TARDE
	return RUTA_NOCHE


static func normalizar_hora(hora: int) -> int:
	# Acepta 0-23. Si por alguna razón llega 1-12 en formato 12h sin
	# distinguir AM/PM no podemos adivinar la mitad del día, así que
	# solo plegamos valores fuera de rango con módulo.
	var h: int = hora % 24
	if h < 0:
		h += 24
	return h


static func hora_actual_dispositivo() -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return normalizar_hora(int(dt.get("hour", 12)))


static func ruta_actual() -> String:
	return ruta_para_hora(hora_actual_dispositivo())


static func aplicar(rect: TextureRect) -> void:
	if rect == null:
		return
	var ruta: String = ruta_actual()
	if ResourceLoader.exists(ruta):
		rect.texture = load(ruta) as Texture2D
