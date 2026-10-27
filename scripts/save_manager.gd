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
var juego_actual_seleccionado: String = "tincanalley"
var nivel_actual_seleccionado: int = 1
var pagina_niveles_por_juego: Dictionary = {}
var premio_recien_desbloqueado: String = ""

func _ready() -> void:
	cargar_progreso()

func cargar_progreso() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		_inicializar_estructura_vacia()
		guardar_a_disco()
		return

	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo:
		var texto = archivo.get_as_text()
		archivo.close()
		var resultado = JSON.parse_string(texto)
		if resultado is Dictionary:
			datos_progreso = resultado
		else:
			_inicializar_estructura_vacia()
	else:
		_inicializar_estructura_vacia()

func _inicializar_estructura_vacia() -> void:
	datos_progreso = {
		"opciones": {
			"musica": true,
			"sfx": true,
			"idioma": "es"
		},
		"games": {}
	}

func guardar_a_disco() -> void:
	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo:
		var json_texto = JSON.stringify(datos_progreso, "\t")
		archivo.store_string(json_texto)
		archivo.close()

# --- REGISTRO Y CONSULTA DE PROGRESO DE NIVELES ---
# --- ESTADO DEL SELECTOR DE NIVELES ---

func obtener_pagina_niveles(id_game: String = "") -> int:
	if id_game == "":
		id_game = juego_actual_seleccionado

	return int(pagina_niveles_por_juego.get(id_game, 1))

func guardar_pagina_niveles(pagina: int, id_game: String = "") -> void:
	if id_game == "":
		id_game = juego_actual_seleccionado

	pagina_niveles_por_juego[id_game] = maxi(pagina, 1)

func registrar_puntaje_nivel(numero_nivel: int, nuevo_puntaje: int, puntaje_maximo: int, id_game: String = "") -> bool:
	if id_game == "": id_game = juego_actual_seleccionado
	
	var clave = str(numero_nivel)
	var puntaje_previo = obtener_puntaje_nivel(numero_nivel, id_game)
	var premios_antes = calcular_cantidad_premios_desbloqueados()

	if nuevo_puntaje > puntaje_previo:
		var dict_juego = _obtener_dict_game(id_game)
		dict_juego[clave] = {
			"score": nuevo_puntaje,
			"max": puntaje_maximo
		}
		guardar_a_disco()

		var premios_despues = calcular_cantidad_premios_desbloqueados()

		if premios_despues > premios_antes and premios_despues <= LISTA_PREMIOS.size():
			premio_recien_desbloqueado = LISTA_PREMIOS[premios_despues - 1]

		return true
	return false

func obtener_puntaje_nivel(numero_nivel: int, id_game: String = "") -> int:
	if id_game == "": id_game = juego_actual_seleccionado
	var clave = str(numero_nivel)
	var dict_juego = _obtener_dict_game(id_game)
	if dict_juego.has(clave):
		return int(dict_juego[clave].get("score", 0))
	return 0

func obtener_maximo_nivel(numero_nivel: int, id_game: String = "") -> int:
	if id_game == "": id_game = juego_actual_seleccionado
	var clave = str(numero_nivel)
	var dict_juego = _obtener_dict_game(id_game)
	if dict_juego.has(clave):
		return int(dict_juego[clave].get("max", 0))
	return 0

func es_nivel_desbloqueado(numero_nivel: int, id_game: String = "") -> bool:
	if id_game == "": id_game = juego_actual_seleccionado
	if numero_nivel == 1:
		return true

	var clave_anterior = str(numero_nivel - 1)
	var dict_juego = _obtener_dict_game(id_game)
	
	if not dict_juego.has(clave_anterior):
		return false

	var datos_prev = dict_juego[clave_anterior]
	var score_prev = float(datos_prev.get("score", 0))
	var max_prev = float(datos_prev.get("max", 1))

	return (score_prev / max_prev) >= (1.0 / 3.0)

func _obtener_dict_game(id_game: String) -> Dictionary:
	if not datos_progreso.has("games"):
		datos_progreso["games"] = {}
	if not datos_progreso["games"].has(id_game):
		datos_progreso["games"][id_game] = {}
	return datos_progreso["games"][id_game]

# --- RECOMPENSAS Y RIBBONS GLOBALES ---

func contar_ribbons_azules() -> int:
	var conteo: int = 0
	var games = datos_progreso.get("games", {})
	
	for nombre_juego in games:
		var niveles = games[nombre_juego]
		if niveles is Dictionary:
			for clave in niveles.keys():
				var info = niveles[clave]
				var score = int(info.get("score", 0))
				var max_score = int(info.get("max", 0))
				if max_score > 0 and score >= max_score:
					conteo += 1
	return conteo

func obtener_total_niveles_game(id_game: String) -> int:
	var config = game_manager.configuracion_juegos.get(id_game, {})
	var ruta = config.get("ruta_niveles_json", "")
	if ruta != "" and FileAccess.file_exists(ruta):
		var texto = FileAccess.get_file_as_string(ruta)
		var datos = JSON.parse_string(texto)
		if datos is Dictionary:
			return datos.keys().size()
	return 0

func obtener_total_niveles_globales() -> int:
	var total_acumulado: int = 0
	for id_juego in game_manager.configuracion_juegos.keys():
		total_acumulado += obtener_total_niveles_game(id_juego)
		
	return max(total_acumulado, 18)

func calcular_cantidad_premios_desbloqueados() -> int:
	var azules = contar_ribbons_azules()
	var total_niveles = obtener_total_niveles_globales()
	var cantidad_premios = LISTA_PREMIOS.size()
	var cantidad_desbloqueada: int = 0

	for i in range(cantidad_premios):
		var numero_premio = i + 1
		var requeridas: int = int(ceil(float(numero_premio) * float(total_niveles) / float(cantidad_premios)))
		if azules >= requeridas:
			cantidad_desbloqueada += 1

	return cantidad_desbloqueada

# --- GESTIÓN DE CONFIGURACIÓN Y PREFERENCIAS GLOBALES ---

func obtener_opcion_audio(clave: String, valor_defecto: bool = true) -> bool:
	if datos_progreso.has("opciones") and datos_progreso["opciones"] is Dictionary:
		return datos_progreso["opciones"].get(clave, valor_defecto)
	return valor_defecto

func guardar_opcion_audio(clave: String, valor: bool) -> void:
	if not datos_progreso.has("opciones") or not (datos_progreso["opciones"] is Dictionary):
		datos_progreso["opciones"] = {}
		
	datos_progreso["opciones"][clave] = valor
	guardar_a_disco()

func obtener_idioma_guardado() -> String:
	if datos_progreso.has("opciones") and datos_progreso["opciones"] is Dictionary:
		return datos_progreso["opciones"].get("idioma", "es")
	return "es"

func guardar_idioma(nuevo_idioma: String) -> void:
	if not datos_progreso.has("opciones") or not (datos_progreso["opciones"] is Dictionary):
		datos_progreso["opciones"] = {}
		
	datos_progreso["opciones"]["idioma"] = nuevo_idioma
	guardar_a_disco()
