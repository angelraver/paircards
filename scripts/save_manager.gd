extends Node

const RUTA_GUARDADO = "user://progreso.json"

const LISTA_PREMIOS: Array[String] = [
	"aros", "dino", "drum",
	"doll", "roboto", "duck",
	"racer", "tricep", "horse",
	"bunny", "plane", "train",
	"rocket", "robot", "teddy",
	"bluey", "astro", "rex"
]

var datos_progreso: Dictionary = {}
var juego_actual_seleccionado: String = "juego"
var nivel_actual_seleccionado: int = 1
var pagina_niveles: int = 1
var premio_recien_desbloqueado: String = ""


func _ready() -> void:
	cargar_progreso()


func cargar_progreso() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		_inicializar_estructura_vacia()
		guardar_a_disco()
		return

	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo == null:
		_inicializar_estructura_vacia()
		return

	var resultado: Variant = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if resultado is Dictionary:
		datos_progreso = resultado
	else:
		_inicializar_estructura_vacia()
	_normalizar_estructura()


func _inicializar_estructura_vacia() -> void:
	datos_progreso = {
		"opciones": {
			"idioma": "es",
			"musica": true,
			"sfx": true,
			"music_enabled": true,
			"sfx_enabled": true
		},
		"levels": {}
	}


func _normalizar_estructura() -> void:
	_obtener_opciones()
	_obtener_levels()
	if datos_progreso.has("games"):
		_migrar_games_a_levels()
		datos_progreso.erase("games")
		guardar_a_disco()


func _migrar_games_a_levels() -> void:
	var juegos: Variant = datos_progreso.get("games", {})
	if not (juegos is Dictionary):
		return

	var levels: Dictionary = _obtener_levels()
	for id_juego in (juegos as Dictionary).keys():
		var niveles: Variant = (juegos as Dictionary)[id_juego]
		if not (niveles is Dictionary):
			continue
		for clave in (niveles as Dictionary).keys():
			var info: Variant = (niveles as Dictionary)[clave]
			if info is Dictionary:
				levels[str(clave)] = {"hi": int((info as Dictionary).get("score", 0))}


func guardar_a_disco() -> void:
	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_string(JSON.stringify(datos_progreso, "\t"))
	archivo.close()


func _obtener_opciones() -> Dictionary:
	if not datos_progreso.has("opciones") or not (datos_progreso["opciones"] is Dictionary):
		datos_progreso["opciones"] = {}
	return datos_progreso["opciones"]


func _obtener_levels() -> Dictionary:
	if not datos_progreso.has("levels") or not (datos_progreso["levels"] is Dictionary):
		datos_progreso["levels"] = {}
	return datos_progreso["levels"]


func obtener_pagina_niveles() -> int:
	return pagina_niveles


func guardar_pagina_niveles(pagina: int) -> void:
	pagina_niveles = maxi(pagina, 1)


func registrar_puntaje_nivel(numero_nivel: int, nuevo_puntaje: int = 0) -> bool:
	if numero_nivel < 1:
		return false

	var clave: String = str(numero_nivel)
	var levels: Dictionary = _obtener_levels()
	var premios_antes: int = calcular_cantidad_premios_desbloqueados()
	var es_nuevo: bool = not levels.has(clave)
	var hi_previo: int = 0
	if not es_nuevo and levels[clave] is Dictionary:
		hi_previo = int((levels[clave] as Dictionary).get("hi", 0))

	var hi_actual: int = maxi(hi_previo, maxi(nuevo_puntaje, 0))
	if not es_nuevo and hi_actual == hi_previo:
		return false

	levels[clave] = {"hi": hi_actual}
	guardar_a_disco()

	var premios_despues: int = calcular_cantidad_premios_desbloqueados()
	if premios_despues > premios_antes and premios_despues <= LISTA_PREMIOS.size():
		premio_recien_desbloqueado = LISTA_PREMIOS[premios_despues - 1]
	return true


func obtener_puntaje_nivel(numero_nivel: int) -> int:
	var levels: Dictionary = _obtener_levels()
	var clave: String = str(numero_nivel)
	if levels.has(clave) and levels[clave] is Dictionary:
		return int((levels[clave] as Dictionary).get("hi", 0))
	return 0


func obtener_maximo_nivel(numero_nivel: int) -> int:
	return obtener_puntaje_nivel(numero_nivel)


func es_nivel_desbloqueado(numero_nivel: int) -> bool:
	if numero_nivel <= 1:
		return true
	return _obtener_levels().has(str(numero_nivel - 1))


func contar_ribbons_azules() -> int:
	return _obtener_levels().size()


func obtener_total_niveles() -> int:
	var config: Dictionary = game_manager.obtener_config_juego_actual() as Dictionary
	var ruta: String = str(config.get("ruta_niveles_json", ""))
	if ruta == "" or not FileAccess.file_exists(ruta):
		return 0

	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not (datos is Dictionary):
		return 0

	var total: int = 0
	for clave in (datos as Dictionary).keys():
		var texto_clave: String = str(clave)
		if texto_clave.is_valid_int() and int(texto_clave) >= 1:
			total += 1
	return total


func obtener_total_niveles_game(_id_game: String = "") -> int:
	return obtener_total_niveles()


func obtener_total_niveles_globales() -> int:
	return obtener_total_niveles()


func calcular_cantidad_premios_desbloqueados() -> int:
	var azules: int = contar_ribbons_azules()
	var total_niveles: int = obtener_total_niveles()
	var cantidad_premios: int = LISTA_PREMIOS.size()
	var cantidad_desbloqueada: int = 0

	for i in range(cantidad_premios):
		var numero_premio: int = i + 1
		var requeridas: int = int(ceil(float(numero_premio) * float(total_niveles) / float(cantidad_premios)))
		if azules >= requeridas:
			cantidad_desbloqueada += 1

	return cantidad_desbloqueada


func obtener_opcion_audio(clave: String, valor_defecto: bool = true) -> bool:
	var opciones: Dictionary = _obtener_opciones()
	if opciones.has(clave):
		return bool(opciones[clave])
	return valor_defecto


func guardar_opcion_audio(clave: String, valor: bool) -> void:
	_obtener_opciones()[clave] = valor
	guardar_a_disco()


func obtener_idioma_guardado() -> String:
	var opciones: Dictionary = _obtener_opciones()
	return str(opciones.get("idioma", "es"))


func guardar_idioma(nuevo_idioma: String) -> void:
	_obtener_opciones()["idioma"] = nuevo_idioma
	guardar_a_disco()
