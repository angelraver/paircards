# skills.md — Referencia rápida: Pair Cards

> Referencia para dar contexto rápido a agentes de IA sobre el estado actual del proyecto.

## 1. Resumen

**Pair Cards** es un juego de emparejar fichas 3D en vista cenital fija. El tablero se genera proceduralmente como una pila de capas sobre una grilla hexagonal circular: las capas impares tienen ficha en el epicentro y las pares se intercalan en los huecos triangulares. El jugador solo puede tocar fichas libres (no cubiertas por fichas de capas superiores) y las envía a una barra inferior de slots para acumular coincidencias.

- **Motor:** Godot 4.7, renderer `mobile` / `gl_compatibility`, física Jolt
- **Resolución:** 720×1280 (portrait), `canvas_items` / `expand`
- **Escena principal:** `res://scenes/title.tscn`
- **Idiomas:** `es` (fallback), `en`, `pt`
- **Persistencia:** `user://progreso.json` (`save_manager`)
- **Exportación:** Web + iOS (`export_presets.cfg`)

**Flujo de navegación:**
`title.tscn` → selección de juego/niveles → `seleccion_niveles.tscn` → `scenes/main.tscn` → `panel_resultados.tscn` (OK → selección/premio, Reiniciar → mismo nivel). Opciones y premios se abren desde el hub.

## 2. Stack y convenciones

| Ítem | Valor |
|------|-------|
| Engine | Godot 4.7 (`config/features=["4.7","Mobile"]`) |
| Renderer | mobile / gl_compatibility |
| Física 3D | Jolt Physics |
| Viewport | 720×1280, `canvas_items/expand`, orientación handheld |
| Main scene | `res://scenes/title.tscn` |
| Persistencia | `user://progreso.json` |
| Export | Web + iOS |

Convenciones: código y comentarios en español, `snake_case` para funciones/variables, recursos/escenas referenciados por UID o rutas `res://`.

## 3. Autoloads (`project.godot`)

| Autoload | Script | Responsabilidad principal |
|----------|--------|---------------------------|
| `save_manager` | `scripts/save_manager.gd` | Progreso y opciones. Estado de sesión (`juego_actual_seleccionado`, `nivel_actual_seleccionado`, página de niveles). API: `registrar_puntaje_nivel`, `obtener_puntaje_nivel`, `obtener_maximo_nivel`, `es_nivel_desbloqueado`, `contar_ribbons_azules`, `obtener_total_niveles_game`, `guardar_a_disco`, opciones audio/idioma. |
| `audio_manager` | `scripts/audio_manager.gd` | BGM y SFX globales. `music_enabled`/`sfx_enabled`, `play_bgm`, `play_start/welldone/prize/ok1/pop/fail`, `ensure_title_bgm`, `ensure_game_bgm(id)`, cache de themes (`assets/sounds/themes/`). |
| `game_manager` | `scripts/game_manager.gd` | Config/localización. Carga `data/games.json`, gestiona idioma (`idioma_actual`, `idioma_cambiado`), carga textos globales y por juego, `obtener_texto`, `obtener_titulo_nivel`, `obtener_config_juego_actual`. |
| `EfectosUI` | autoload configurado en proyecto | Autoload de efectos UI (configurado por UID en `project.godot`). |
| `InAppUpdate` | autoload configurado en proyecto | Autoload de actualización in-app (configurado por UID). |

## 4. Navegación y escenas (`scenes/`)

| Escena | Script | Rol |
|--------|--------|-----|
| `title.tscn` | `title.gd` | Hub inicial/carrusel y acceso a juegos, premios y opciones. |
| `seleccion_niveles.tscn` | `seleccion_niveles.gd` | Selector de niveles data-driven (lee `games.json`/config del juego). |
| `slot_nivel.tscn` | `slot_nivel.gd` | Slot de nivel (estado bloqueado/desbloqueado, ribbons). |
| `main.tscn` | `main.gd` | Partida: tablero 3D, barra, HUD, pausa y resultados. |
| `panel_pausa.tscn` | `panel_pausa.gd` | Pausa en partida (toggles música/SFX, home). |
| `panel_resultados.tscn` | `panel_resultados.gd` | Fin de nivel; señal `reiniciar_solicitado`. OK navega a premio desbloqueado o selección de niveles. |
| `puntos_flotantes.tscn` | — | Label flotante animado usado para mostrar puntos en partida. |
| `ui_level_number.tscn` | `ui_level_number.gd` | Indicador de nivel (`establecer_nivel`). |
| `options.tscn` | `options.gd` | Opciones (música, SFX, idioma). |
| `premios.tscn` | `premios.gd` | Galería de premios. |
| `premio_desbloqueado.tscn` | `premio_desbloqueado.gd` | Pantalla de premio desbloqueado. |
| `audio_manager.tscn` | `audio_manager.gd` | Contenedor/escena del audio global. |
| `juego_audio_manager.tscn` | `juego_audio_manager.gd` | Audio SFX específico del juego (instancia en `main.tscn`). |
| `austral_animated_logo.tscn` | `austral_animated_logo.gd` | Animación de logo. |

## 5. Datos y configuración

### Registro de juego — `data/games.json`
```json
{
  "juego": {
    "escena_juego": "res://scenes/main.tscn",
    "ruta_niveles_json": "res://data/niveles.json",
    "textos_json": "res://data/juego_textos.json",
    "textura_logo": "res://assets/images/juego_logo.webp",
    "prefijo_texto": "juego_"
  }
}
```

### Niveles — `data/niveles.json`
Definición por id de nivel (string). Campos usados por `main.gd`:
- `capas` (int): número de capas del tablero (>=1). Capa 1 = superior.
- `slots` (int): cantidad de espacios en la barra inferior (1..5, centrados horizontalmente).
- `fichas_n` (int): cantidad objetivo de fichas a colocar (se ajusta a par y al máximo posible por capacidad).
- `fichas_t` (Array): claves de tipos permitidos para el nivel.

Ejemplo actual:
```json
{
  "1": { "capas": 3, "slots": 2, "fichas_n": 64, "fichas_t": ["a","b","c","d","e","f"] }
}
```

### Catálogo de tipos — `data/valores.json`
Mapea claves de tipo a nombres de textura (astronomía):
```json
{ "fichas": { "a": "cometa", "b": "cruz", "...": "..." } }
```
Textura final: `res://assets/images/astronomia/<nombre>.png`.

### Textos
- `data/textos.json`: textos globales/localizados del proyecto.
- `data/juego_textos.json`: textos del juego (p.ej. títulos de nivel) cargados con `prefijo_texto` (`juego_`).

## 6. Mecánicas de juego (`scripts/main.gd`)

Nodo raíz de partida (`extends Node3D`). Carga config, genera nivel y gestiona input, barra y fin de partida.

### Generación del tablero
- **Modelo de ficha:** `res://assets/models/ficha.glb` + shader `res://shaders/ficha_cara.gdshader` (textura en cara superior). Clase interna `FichaTablero` (tipo, capa, celda axial, estado libre, colisión cilíndrica para raycast).
- **Grilla:** red hexagonal recortada por radio circular (`RADIO_MAX_CAPA`). Capas impares centradas en epicentro; capas pares desplazadas al hueco triangular (`DESPLAZAMIENTO_INTERCALADO`) para intercalarse.
- **Reparto:** calcula capacidad por capa, limita a `fichas_n` (par) quitando desde capas inferiores si hace falta, genera parejas aleatorias con tipos de `fichas_t`, baraja y asigna a celdas aleatorias por capa.
- **Entrada:** fichas caen desde altura inicial con animación escalonada (capas inferiores primero).

### Visibilidad y selección
- **Libre:** una ficha es seleccionable si ninguna ficha de capa superior (número de capa menor) se superpone en plano XZ (comparación de distancia entre centros de círculos del mismo diámetro).
- **Feedback:** fichas bloqueadas se oscurecen según capa (`OSCURIDAD_BASE_CAPAS`).
- **Input:** tap/click → raycast (`CAPA_COLISION_FICHAS`) → selecciona ficha libre si no hay animación de entrada, pausa o panel de resultados.

### Barra inferior y combo
- **Barra:** renderizada como quad 3D sobre el piso (SubViewport + Sprite3D) con fondo/UI 2D y slots centrados (`HBoxContainer`, `ALIGNMENT_CENTER`). Cantidad de slots = `slots` del nivel (dinámico, 1..5).
- **Al seleccionar ficha libre:** vuela a la barra (salto + trayectoria en arco + rotación). Si su tipo ya existe en algún slot, se acumula en ese slot (reinicia ventana de combo de 2s al aterrizar y pasa a ser el slot activo). Si es tipo nuevo, ocupa un slot libre (o derrota si no hay libres). Slots con ficha en vuelo pueden ocultar icono hasta aterrizar.
- **Ventana de combo:** `TIEMPO_COMBO = 2.0s`, se inicia/reinicia al aterrizar una ficha en el slot activo. Si expira con vuelo pendiente al slot activo, la resolución se difiere.
- **Resolución:**
  - Acumulación `>= 2` en el slot: desaparece al expirar la ventana sin nueva coincidencia o al romperse el combo por seleccionar otra cara; muestra humo y total de puntos.
  - Acumulación `1` (solitaria): permanece en su slot.
  - Cambiar de cara/foco rompe el combo activo previo (resolviéndolo según regla anterior).
- **Puntos flotantes:** instancia `scenes/puntos_flotantes.tscn` en capa de efectos; muestra `+N` al aterrizar una acumulación (`N = contador-1`) y el total al desaparecer el grupo.

### Fin de partida
- **Victoria:** tablero vacío y barra vacía.
- **Derrota:** se intenta colocar un tipo nuevo sin slot libre.
- Muestra mensaje breve y abre `panel_resultados` vía `ControladorResultados`.

### Nodos relevantes en `main.tscn` (referenciados por `main.gd`)
`BoardElements` (contenedor fichas), `Camera3D`, `UI/LevelNumber`, `UI/LevelTitle`, `UI/PanelResultados`, `UI/BotonPausa`, `UI/PanelPausa`, `AudioJuego` (escena `juego_audio_manager.tscn`), y luces (`DirectionalLight3D`, `SunLight`) usadas para iconos 3D de la barra.

## 7. Audio

- **Global (`audio_manager.gd`):** controla BGM y SFX habilitados (persistidos), reproduce SFX comunes (`ok1`, `start`, `welldone`, `prize`, `pop`, `fail`) y gestiona temas BGM (`ensure_title_bgm`, `ensure_game_bgm`).
- **Juego (`juego_audio_manager.gd`, `extends GameAudioBase`):** crea dinámicamente players para `drop1..drop4` y `select` (`assets/sounds/`), expone `play_drop()`, `play_select()`, `play_selected()`. Respeta `sfx_enabled` vía `GameAudioBase`.
- **Pausa:** `panel_pausa.gd` pausa el árbol (`SceneTree.paused`) sin cortar la música (BGM en `PROCESS_MODE_ALWAYS`).

## 8. Controladores y utilidades reutilizables

| Script | class_name | Uso |
|--------|------------|-----|
| `controlador_resultados.gd` | `ControladorResultados` | Orquesta `PanelResultados`: reset/mostrar, ocultar-restaurar HUD, conexión de reinicio, actualización de nivel. |
| `panel_resultados.gd` | `PanelResultados` | UI de fin de nivel, señal `reiniciar_solicitado`, navegación OK. |
| `game_audio_base.gd` | `GameAudioBase` | Agrupa `AudioStreamPlayer` por prefijo numérico y reproduce respetando SFX habilitado. |
| `panel_pausa.gd` | `PanelPausa` | Lógica de pausa. |
| `ui_level_number.gd` | `UILevelNumber` | Muestra número de nivel. |
| `slot_nivel.gd` | `SlotNivel` (según escena/script) | Representación de nivel en selector. |
| `fondo_dinamico.gd`, `logo_script.gd`, `label.gd` | — | Soporte visual/UI en pantallas. |

## 9. Progresión, ribbons y premios

- **Progreso por nivel:** `save_manager` guarda score/max por juego y nivel en `user://progreso.json`.
- **Desbloqueo:** nivel 1 siempre disponible; nivel `n` se desbloquea si `score(n-1)/max(n-1) >= 1/3`.
- **Ribbons (por desempeño):** amarilla ≥ 1/3, roja ≥ 2/3, azul = 100% (`score >= max`), con conteo global de azules.
- **Premios:** lista global de 18 premios; desbloqueo progresivo según ribbons azules/totales (cálculo en `save_manager`), con pantalla de premio desbloqueado cuando corresponde.

## 10. Estructura de archivos (resumen)

```
.
├── project.godot
├── export_presets.cfg
├── data/
│   ├── games.json
│   ├── niveles.json
│   ├── valores.json
│   ├── textos.json
│   └── juego_textos.json
├── scripts/
│   ├── main.gd                    # lógica principal de la partida
│   ├── juego_audio_manager.gd
│   ├── game_audio_base.gd
│   ├── controlador_resultados.gd
│   ├── panel_resultados.gd / panel_pausa.gd
│   ├── save_manager.gd / audio_manager.gd / game_manager.gd
│   ├── title.gd / seleccion_niveles.gd / slot_nivel.gd / options.gd
│   ├── premios.gd / premio_desbloqueado.gd / ui_level_number.gd
│   └── soporte UI (fondo_dinamico.gd, logo_script.gd, label.gd, ...)
├── scenes/
│   ├── main.tscn, title.tscn, seleccion_niveles.tscn, slot_nivel.tscn
│   ├── panel_resultados.tscn, panel_pausa.tscn, puntos_flotantes.tscn
│   ├── options.tscn, premios.tscn, premio_desbloqueado.tscn
│   ├── audio_manager.tscn, juego_audio_manager.tscn, ui_level_number.tscn
│   └── austral_animated_logo.tscn
├── shaders/                       # ficha_cara.gdshader, efectos visuales
├── assets/
│   ├── images/astronomia/         # texturas de fichas (<nombre>.png)
│   ├── images/                    # UI, logos, premios, fondos
│   ├── models/ficha.glb
│   ├── fonts/
│   └── sounds/ (+ themes/)
└── skill.md
```

## 11. Notas para agentes

- La generación y reglas de partida viven en `scripts/main.gd`; los parámetros de nivel vienen de `data/niveles.json` y el mapeo de tipos/texturas de `data/valores.json`.
- Para agregar/modificar niveles, mantener claves consistentes entre `fichas_t` (niveles) y `fichas` (valores) y asegurar textura en `assets/images/astronomia/`.
- `slots` en nivel controla la dificultad/capacidad de la barra (1..5) y la UI se adapta dinámicamente.
- Puntos flotantes en partida se crean instanciando `scenes/puntos_flotantes.tscn` desde `main.gd`; SFX del juego pasan por `juego_audio_manager` (`GameAudioBase`).
- Validar cambios en Godot 4.7 (no hay linter/typecheck de GDScript configurado en este entorno).
