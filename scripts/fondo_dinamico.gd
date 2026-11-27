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


static func indice_franja_para_hora(hora: int) -> int:
	var h: int = normalizar_hora(hora)
	if h >= HORA_DIA_INICIO and h < HORA_TARDE_INICIO:
		return 0
	if h >= HORA_TARDE_INICIO and h < HORA_NOCHE_INICIO:
		return 1
	return 2


static func ruta_para_franja(indice: int, ruta_dia: String, ruta_tarde: String, ruta_noche: String) -> String:
	if indice == 0:
		return ruta_dia
	if indice == 1:
		return ruta_tarde
	return ruta_noche


static func ruta_para_hora(hora: int) -> String:
	return ruta_para_franja(indice_franja_para_hora(hora), RUTA_DIA, RUTA_TARDE, RUTA_NOCHE)


static func ruta_actual_entre(ruta_dia: String, ruta_tarde: String, ruta_noche: String) -> String:
	return ruta_para_franja(indice_franja_para_hora(hora_actual_dispositivo()), ruta_dia, ruta_tarde, ruta_noche)


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
	var ruta: String = ruta_actual_entre(RUTA_DIA, RUTA_TARDE, RUTA_NOCHE)
	if ResourceLoader.exists(ruta):
		var textura: Texture2D = load(ruta) as Texture2D
		if textura != null:
			rect.texture = textura


static func aplicar_material(material: Material, ruta_dia: String, ruta_tarde: String, ruta_noche: String) -> void:
	if not (material is StandardMaterial3D):
		return
	var ruta: String = ruta_actual_entre(ruta_dia, ruta_tarde, ruta_noche)
	if not ResourceLoader.exists(ruta):
		return
	var textura: Texture2D = load(ruta) as Texture2D
	if textura != null:
		(material as StandardMaterial3D).albedo_texture = textura
