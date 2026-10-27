extends Node

signal idioma_cambiado(nuevo_idioma: String)

const RUTA_GAMES_JSON: String = "res://data/games.json"

var idioma_actual: String = "es"
var configuracion_juegos: Dictionary = {}
var textos_locales: Dictionary = {}

func _ready() -> void:
	cargar_configuracion_juegos()
	idioma_actual = save_manager.obtener_idioma_guardado()
	cargar_todos_los_textos()

func cargar_configuracion_juegos() -> void:
	configuracion_juegos.clear()
	
	if not FileAccess.file_exists(RUTA_GAMES_JSON):
		print("ERROR: No se encontró el archivo de juegos en: ", RUTA_GAMES_JSON)
		return

	var texto_json = FileAccess.get_file_as_string(RUTA_GAMES_JSON)
	var resultado = JSON.parse_string(texto_json)

	if resultado is Dictionary:
		configuracion_juegos = resultado
	else:
		print("ERROR: Formato inválido en el JSON de juegos: ", RUTA_GAMES_JSON)

func cambiar_idioma(nuevo_idioma: String) -> void:
	if idioma_actual != nuevo_idioma:
		idioma_actual = nuevo_idioma
		save_manager.guardar_idioma(nuevo_idioma)
		idioma_cambiado.emit(nuevo_idioma)

func cargar_todos_los_textos() -> void:
	textos_locales.clear()
	
	# 1. Cargar textos globales
	_cargar_archivo_texto("res://data/textos.json", "")
	
	# 2. Cargar textos de todos los juegos registrados en la configuración
	for id_juego in configuracion_juegos.keys():
		var config = configuracion_juegos[id_juego]
		_cargar_archivo_texto(config.get("textos_json", ""), config.get("prefijo_texto", ""))

func _cargar_archivo_texto(ruta: String, prefijo: String) -> void:
	if ruta != "" and FileAccess.file_exists(ruta):
		var texto_json = FileAccess.get_file_as_string(ruta)
		var resultado = JSON.parse_string(texto_json)
		if resultado is Dictionary:
			for clave in resultado.keys():
				var clave_final = prefijo + str(clave)
				textos_locales[clave_final] = resultado[clave]

func obtener_config_juego_actual() -> Dictionary:
	return configuracion_juegos.get(save_manager.juego_actual_seleccionado, {})

func obtener_texto(clave: String, texto_defecto: String = "") -> String:
	var clave_str = str(clave)
	if textos_locales.has(clave_str):
		var data_clave = textos_locales[clave_str]
		if data_clave is Dictionary:
			if data_clave.has(idioma_actual) and str(data_clave[idioma_actual]).strip_edges() != "":
				return str(data_clave[idioma_actual])
			elif data_clave.has("es") and str(data_clave["es"]).strip_edges() != "":
				return str(data_clave["es"])
				
	return texto_defecto if texto_defecto != "" else clave_str

func obtener_titulo_nivel(id_nivel: Variant, id_game: String = "") -> String:
	if id_game == "":
		id_game = save_manager.juego_actual_seleccionado

	var num_str = str(id_nivel)
	var fallback_titulo = "Nivel " + num_str
	
	var config = configuracion_juegos.get(id_game, {})
	var prefijo = config.get("prefijo_texto", id_game + "_")
	
	var clave_con_prefijo = "%s%s" % [prefijo, num_str]
	if textos_locales.has(clave_con_prefijo):
		return obtener_texto(clave_con_prefijo, fallback_titulo)
		
	if textos_locales.has(num_str):
		return obtener_texto(num_str, fallback_titulo)
		
	return fallback_titulo
