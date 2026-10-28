extends Node
class_name ControladorResultados

## Controlador reutilizable para el flujo estándar de PanelResultados.
## Extrae la duplicación de los 3 minijuegos (tincanalley, whackamole, plinko):
##  - reset de flag + ocultar panel al iniciar nivel
##  - guard + ocultar HUD + mostrar panel al finalizar
##  - conexión de reiniciar_solicitado -> callback
##  - actualización de UIPuntaje / UILevelNumber
##
## Uso:
##   @onready var ctrl_resultados := ControladorResultados.new()
##   func _ready():
##       add_child(ctrl_resultados)
##       ctrl_resultados.configurar(panel_resultados, [ui_puntaje, ui_level_number, barra_energia], ui_puntaje, ui_level_number, reiniciar_nivel)
##   func cargar_nivel(n):
##       ctrl_resultados.reset() # o al_iniciar_nivel()
##       ...
##   func mostrar_panel_resultados():
##       ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)

@export var panel_resultados: PanelResultados
@export var hud_a_ocultar: Array[CanvasItem]
@export var ui_level_number: UILevelNumber

var _mostrado: bool = false
var _reiniciar_callback: Callable

func _ready() -> void:
	# Soporte para instanciación vía escena: si los exports ya están seteados
	# y hay un callback válido, asegura visibilidad inicial.
	if panel_resultados and _reiniciar_callback.is_valid():
		_asegurar_conexion()

## Configura el controlador con las dependencias del juego.
## [param p_hud] lista de nodos HUD que deben ocultarse al mostrar resultados y restaurarse al reset.
func configurar(p_panel: PanelResultados, p_hud: Array, p_ui_level: UILevelNumber, p_reiniciar_callback: Callable) -> void:
	panel_resultados = p_panel
	# Conversión tolerante: p_hud puede venir como Array genérico literal [ui_puntaje, ...]
	hud_a_ocultar.clear()
	for item in p_hud:
		if item is CanvasItem:
			hud_a_ocultar.append(item)
	ui_level_number = p_ui_level
	_reiniciar_callback = p_reiniciar_callback
	_mostrado = false
	if panel_resultados:
		panel_resultados.visible = false
		_asegurar_conexion()

func _asegurar_conexion() -> void:
	if panel_resultados and _reiniciar_callback.is_valid():
		if not panel_resultados.reiniciar_solicitado.is_connected(_on_reiniciar_solicitado):
			panel_resultados.reiniciar_solicitado.connect(_on_reiniciar_solicitado)

## Llamar al inicio de cargar_nivel: resetea flag, oculta panel y restaura HUD.
func reset() -> void:
	_mostrado = false
	if panel_resultados:
		panel_resultados.visible = false
	for n in hud_a_ocultar:
		if is_instance_valid(n):
			n.visible = true

## Alias semántico de reset(), mantiene compatibilidad con el comentario estándar.
func al_iniciar_nivel() -> void:
	reset()

## Guard + ocultar HUD + mostrar PanelResultados.
func mostrar(nivel_actual: int) -> void:
	if not panel_resultados:
		return
	if _mostrado:
		return
	_mostrado = true
	for n in hud_a_ocultar:
		if is_instance_valid(n):
			n.visible = false
	panel_resultados.mostrar(nivel_actual)


func actualizar_nivel(nivel: int) -> void:
	if ui_level_number:
		ui_level_number.establecer_nivel(nivel)

func esta_mostrado() -> bool:
	return _mostrado

func _on_reiniciar_solicitado() -> void:
	if _reiniciar_callback.is_valid():
		_reiniciar_callback.call()
