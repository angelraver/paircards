# skills.md — Referencia rápida: Pair Cards

> Proyecto único de Godot 4.7. Todo vive en la raíz; no hay carpetas `core/` ni `games/`.

---

## 1) Resumen del proyecto

**Pair Cards** es un juego de emparejar fichas 3D en vista cenital sobre un tablero hexagonal apilado en 5 capas.

- **Motor:** Godot 4.7, renderer mobile / gl_compatibility, física Jolt
- **Pantalla:** 720×1280 portrait, `canvas_items` / `expand`
- **Escena principal:** `res://scenes/title.tscn`
- **Exportación:** Web + iOS (`export_presets.cfg`)
- **Idiomas:** es (fallback) / en / pt
- **Persistencia:** `user://progreso.json` vía `save_manager`
- **Audio:** `audio_manager` (BGM + SFX) con temas por juego en `assets/sounds/themes/`

**Flujo de navegación:**

```
title.tscn (hub, carrusel)
  └─► seleccionar "juego"
      └─► seleccion_niveles.tscn (9 por página, data-driven)
            └─► tap nivel
                  └─► scenes/main.tscn (partida)
                        └─► panel_resultados.tscn (fin de nivel)
                              └─► OK → seleccion_niveles.tscn
                              └─► Reiniciar → main.tscn (mismo nivel)
                              └─► Premio nuevo → premio_desbloqueado.tscn
```

---

## 2) Stack y convenciones

| Ítem | Valor |
|------|-------|
| Engine | Godot 4.7 (`config/features=["4.7","Mobile"]`) |
| Renderer | mobile / gl_compatibility |
| Física 3D | Jolt Physics |
| Viewport | 720×1280, `canvas_items/expand`, orientación handheld |
| Main scene | `res://scenes/title.tscn` |
| Idiomas | es / en / pt |
| Persistencia | `user://progreso.json` |
| Export | Web + iOS |

**Convenciones:** código y comentarios en **español**, `snake_case` para funciones/variables, UIDs de Godot en `project.godot` y `*.tscn`.

---

## 3) Autoloads (`project.godot`)

| Autoload | Script | Qué expone |
|----------|--------|------------|
| `save_manager` | `scripts/save_manager.gd` | `juego_actual_seleccionado`, `nivel_actual_seleccionado`, `registrar_puntaje_nivel(nivel,puntaje,max,id_game)`, `obtener_puntaje_nivel`, `obtener_maximo_nivel`, `es_nivel_desbloqueado(nivel,id_game)`, `contar_ribbons_azules()`, `obtener_total_niveles_game(id)`, `guardar_a_disco()`, opciones de audio/idioma |
| `audio_manager` | `scripts/audio_manager.gd` | `music_enabled`, `sfx_enabled`, `bgm_player`, `play_bgm(stream)`, `play_start/welldone/prize/ok1/pop/fail()`, `ensure_title_bgm()`, `ensure_game_bgm(id)` |
| `game_manager` | `scripts/game_manager.gd` | `idioma_actual`, `configuracion_juegos` (cache de `games.json`), `textos_locales`, `cargar_configuracion_juegos()`, `obtener_texto(clave,defecto)`, `obtener_titulo_nivel(id)`, signal `idioma_cambiado` |

---

## 4) Controladores reutilizables (`class_name`)

| Script | class_name | Para qué |
|--------|------------|----------|
| `scripts/controlador_resultados.gd` | `ControladorResultados` | `reset()/al_iniciar_nivel()`, `mostrar(nivel_actual)`, `actualizar_nivel(n)`, `esta_mostrado()`, signal `reiniciar_solicitado`. Oculta/restaura HUD al mostrar resultados. |
| `scripts/game_audio_base.gd` | `GameAudioBase` | Agrupa `AudioStreamPlayer` hijos por prefijo. `play(prefijo)`, `play_aleatorio(prefijo)`, respeta `sfx_enabled`. |
| `scripts/panel_resultados.gd` | `PanelResultados` | `mostrar(nivel_id)` → panel fin de nivel. Señal `reiniciar_solicitado`. Botón OK va a `seleccion_niveles.tscn` (o `premio_desbloqueado.tscn` si hay premio). |
| `scripts/carousel_menu.gd` | `CarouselMenu` | Carrusel cilíndrico del hub (title), drag + inercia + snap. |
| `scripts/panel_pausa.gd` | `PanelPausa` | Pausa dentro de partida, toggles música/SFX + botón Home. |
| `scripts/ui_puntaje.gd` | `UIPuntaje` | `establecer_puntaje(int)` / `establecer_maximo(int)`. |
| `scripts/ui_timer.gd` | `UITimer` | Countdown, signal `tiempo_agotado`. |
| `scripts/ui_level_number.gd` | `UILevelNumber` | `establecer_nivel(int)`. |

---

## 5) Pantallas / escenas (`scenes/`)

| Escena | Script | Reutilización |
|--------|--------|---------------|
| `title.tscn` | `title.gd` | Hub: carrusel dinámico, botones Juegos / Premios / Opciones. |
| `seleccion_niveles.tscn` | `seleccion_niveles.gd` | Genérica, data-driven. Lee `games.json`, fondo dinámico por hora, 9 niveles/página. |
| `slot_nivel.tscn` | `slot_nivel.gd` | Slot individual, bloqueado/desbloqueado con ribbons. |
| `panel_resultados.tscn` | `panel_resultados.gd` | Panel fin de nivel. |
| `puntos_flotantes.tscn` | — | Usado por `EfectosUI` (texto flotante + fade 1.5s). |
| `options.tscn` | `options.gd` | Toggles música/SFX + selector idioma es/en/pt. |
| `premios.tscn` | `premios.gd` | Galería de 18 premios. |
| `premio_desbloqueado.tscn` | `premio_desbloqueado.gd` | Celebración de premio nuevo. |
| `audio_manager.tscn` | `audio_manager.gd` | Contenedor SFX del core (ok/welldone/prize/pop/fail). |
| `panel_pausa.tscn` | `panel_pausa.gd` | Pausa en partida. |
| `austral_animated_logo.tscn` | `austral_animated_logo.gd` | Splash/animación de logo. |
| `juego_audio_manager.tscn` | `juego_audio_manager.gd` | SFX propios del juego (`pik1/pik2/points`). Extiende `GameAudioBase`. |

---

## 6) Registro del juego — `data/games.json`

Solo entra un juego:

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

Campos: `escena_juego`, `ruta_niveles_json`, `textos_json`, `textura_logo` (`.webp`), `prefijo_texto`.

---

## 7) Juego — datos y escena `main.tscn`

### Datos
- `data/niveles.json`: niveles `"1".."N"` contiguos. Cada uno tiene `puntaje`, `color_board`, `color_peg`, `color_ramp`, `pegs[{x,y}]`, `ramps[{x,y,rot}]`, `slots[{x_start,x_end,pts,color}]`.
- `data/juego_textos.json`: títulos de nivel con prefijo `juego_`.
- `scenes/main.tscn`: escena jugable (tablero, pegs, ramps, slots, bola, cámara, UI).

### Scripts propios del juego
`main.gd`, `ball.gd`, `board_frame.gd`, `color_utils.gd`, `peg.gd`, `ramp.gd`, `slot.gd`, `juego_audio_manager.gd`.

---

## 8) Patrón `main.gd`

```gdscript
extends Node3D

const MAX_BALLS: int = 5

@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego

var nivel_actual: int = 1
var ctrl_resultados: ControladorResultados

func _ready() -> void:
  nivel_actual = save_manager.nivel_actual_seleccionado
  ctrl_resultados = ControladorResultados.new()
  add_child(ctrl_resultados)
  ctrl_resultados.configurar(panel_resultados, [ui_level_number, boton_pausa, _barra_ui], ui_level_number, reiniciar_nivel)
  cargar_nivel(nivel_actual)

func cargar_nivel(n: int) -> void:
  ctrl_resultados.reset()
  ctrl_resultados.actualizar_nivel(n)

func _on_puntos_ganados(pts: int, pos3d: Vector3) -> void:
  puntaje_nivel += pts
  ctrl_resultados.actualizar_puntaje(puntaje_nivel)
  EfectosUI.crear_efecto_puntos(pos3d, pts)

func mostrar_panel_resultados() -> void:
  ctrl_resultados.mostrar(nivel_actual)

func reiniciar_nivel() -> void:
  cargar_nivel(nivel_actual)
```

---

## 9) Progresión, ribbons y premios

- **Desbloqueo de nivel n:** `score(n-1) / max(n-1) >= 1/3`. Nivel 1 siempre desbloqueado.
- **Ribbons:** amarilla ≥ 1/3, roja ≥ 2/3, azul = 100% (`score >= max`).
- **Premios globales:** 18 premios (`aros`, `dino`, `drum`, `doll`, `roboto`, `duck`, `racer`, `tricep`, `horse`, `bunny`, `plane`, `train`, `rocket`, `robot`, `teddy`, `bluey`, `astro`, `rex`).
  - `azules = contar_ribbons_azules()`
  - Para premio `i` (1-indexado): `requeridas = ceil(i * total_niveles / 18)`
- **Localización:** `data/textos.json` (core) + `data/juego_textos.json` (prefijo `juego_`). `obtener_texto` con fallback `es`.

---

## 10) Estructura de archivos

```
.
├── project.godot              # autoloads, viewport 720×1280, Jolt, main_scene title.tscn
├── export_presets.cfg
├── data/
│   ├── games.json             ← registry (único juego)
│   ├── textos.json            ← textos globales es/en/pt
│   ├── juego_textos.json      ← títulos de nivel (prefijo juego_)
│   └── niveles.json           ← definición de niveles
├── scripts/                   # autoloads + controladores + scripts de juego
├── scenes/                    # todas las pantallas
├── shaders/                   # desenfoque, chromatic_aberration, crt_effect, logo_dissolver
├── assets/
│   ├── fonts/                 # carnivalee_freakshow.ttf, evereast.ttf, PressStart2P-Regular.ttf
│   ├── images/
│   │   ├── ui/                # botones, iconos, ribbons, paneles
│   │   ├── prizes/            # 18 PNG de premios
│   │   ├── fondodia/tarde/noche.webp, logo.webp, logoaustral.webp
│   │   └── juego_logo.webp
│   ├── models/board.glb
│   └── sounds/
│       ├── *.wav (SFX del core)
│       └── themes/            # main_theme.ogg, juego.ogg
└── skills.md
```

---

## 11) Qué hacer / qué NO hacer

**Hacer:**
- Usar `save_manager.juego_actual_seleccionado` para el id de juego actual.
- Usar `EfectosUI.crear_efecto_puntos(pos3D, pts)` para puntos flotantes.
- Usar `audio_manager.play_ok1()` en clicks de botones UI.
- Usar `game_manager.obtener_texto(clave)` con fallback `es`.
- Respetar `prefijo_texto` (`juego_`) para evitar colisiones de textos.

**No hacer:**
- No crear `res://core/` ni `res://games/` — ya no existen.
- No hardcodear `id` de juego.
- No duplicar lógica de ribbons/desbloqueo — usar `save_manager` y `panel_resultados`.
- No instanciar `puntos_flotantes.tscn` directo.
- No añadir `AudioStreamPlayer` sueltos sin `GameAudioBase` (pierdes `sfx_enabled`).

---

## 12) Ejecución

Abrir la raíz en **Godot 4.7+** → Run (main scene = `title.tscn`). Export vía `Project → Export` (presets Web/iOS en `export_presets.cfg`).

---
*Referencia rápida generada a partir del código fuente del proyecto. Última revisión: estructura actual (un solo juego, arquitectura unificada en raíz).*
