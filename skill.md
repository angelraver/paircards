# Plinko — Skill Guide para Agentes

> **Para agentes (Muse, Codex, LLM).** Este README es la skill canónica del proyecto.
> Si tu tarea es **tocar HUD/pantallas, progresión, audio, localización o el único juego (plinko)**, lee este archivo primero. No hay carpetas `core/` ni `games/`: todo vive en la raíz como un **solo juego íntegro**.

Juego único 3D estilo feria/carnival: **Plinko**, construido con **Godot 4.7 — Mobile renderer, portrait 720×1280, Jolt Physics**. Export: **Web + iOS**. Flujo: `title` (hub/carrusel) → `seleccion_niveles` → `main` (plinko).

---

## 1) Stack y convenciones rápidas

| Item | Valor |
|---|---|
| Engine | Godot 4.7 (`config/features=[4.7, Mobile]` en `project.godot:14`) |
| Renderer | `mobile` / `gl_compatibility` (`project.godot:40-41`) |
| Física 3D | Jolt Physics (`project.godot:35`) |
| Viewport | 720×1280, `canvas_items/expand` (`project.godot:27-31`) |
| Main scene | `res://scenes/title.tscn` (uid `cokb2wqhdfvfb` en `project.godot:14`) |
| Idiomas | `es` (fallback) / `en` / `pt` |
| Persistencia | `user://progreso.json` vía `save_manager.gd` |
| Export | `export_presets.cfg` (Web + iOS) |

Convenciones: código y comentarios en **español**, `snake_case` para funciones/variables, UIDs de Godot para `project.godot` y `*.tscn`.

---

## 2) Arquitectura — mapa mental

```
┌────────────────────────────── RAÍZ (un solo juego: plinko) ──────────────────────────────┐
│  title (hub, carrusel) ──► seleccion_niveles (genérica, 9/pág) ──► scenes/main.tscn (plinko) │
│       │                    ▲                                 │              │              │
│       ├──► premios         │                          PanelResultados       │              │
│       └──► options    data/games.json (registry, SOLO plinko)           EfectosUI        │
│                              ▲  ▲  ▲                                              │              │
│                              │  │  └─► textos.json + prefijo plinko_           │              │
│  Autoloads: save_manager · audio_manager · game_manager · EfectosUI (+ InAppUpdate)      │
│  HUD compartido: UIPuntaje · UITimer · UILevelNumber · PuntosFlotantes                    │
│  Shaders: desenfoque / chromatic_aberración / crt_effect / logo_dissolver                 │
└───────────────────────────────────────────────────────────────────────────────────────────┘
                │              │               │              │               │
         scripts/           scenes/           data/           assets/         shaders/
   (autoloads + controllers)  (todas las pantallas)  (games.json, niveles, textos)  (fonts, images, sounds, models)
```

**Regla de oro:** No hay `core/` ni `games/`. `scripts/` no importa nada de `scenes/` de juego ajeno: hay un solo juego. Todo se acopla por 3 puntos: `data/games.json`, lectura de `save_manager.nivel_actual_seleccionado`, y `PanelResultados`.

---

## 3) Inventario de recursos reutilizables — raíz

### 3.1 Autoloads (`project.godot:18-23`, `scripts/`)

| Autoload | Script | Qué expone |
|---|---|---|
| `save_manager` | `scripts/save_manager.gd:1` | `juego_actual_seleccionado`, `nivel_actual_seleccionado`, `registrar_puntaje_nivel(nivel,puntaje,max,id_game)`, `obtener_puntaje_nivel`, `es_nivel_desbloqueado(nivel,id_game)`, `contar_ribbons_azules()`, `obtener_total_niveles_game(id)`, `guardar_a_disco()`, etc. |
| `audio_manager` | `scripts/audio_manager.gd:1` | `music_enabled/sfx_enabled`, `bgm_player`, `play_bgm(stream)`, `play_start/welldone/prize/ok1/pop/fail()`, `ensure_title_bgm()` (`main_theme.ogg`), `ensure_game_bgm(id)` (tema de `assets/sounds/themes/<juego>.ogg`; hoy solo `plinko`). Estado leído de `save_manager`. Click del core: `play_ok1()`. |
| `game_manager` | `scripts/game_manager.gd:1` | `idioma_actual`, `configuracion_juegos` (cache de `games.json`), `textos_locales`, `cargar_configuracion_juegos()`, `obtener_texto(clave,defecto)` con fallback `es`, `obtener_titulo_nivel(id)` resuelve `prefijo+num`, signal `idioma_cambiado`. |
| `EfectosUI` | `scripts/efectos_ui.gd:1` | `crear_efecto_puntos(posicion_3d, valor)` — instancia `scenes/puntos_flotantes.tscn`, animación flotante+fade 1.5s. |

### 3.2 Controladores reutilizables (`class_name`)

| Script | `class_name` | Para qué |
|---|---|---|
| `scripts/controlador_resultados.gd` | `ControladorResultados` | `reset()/al_iniciar_nivel()`, `mostrar(nivel,puntaje,max)`, `actualizar_puntaje/nivel/maximo`, `esta_mostrado()`, signal `reiniciar_solicitado`. |
| `scripts/game_audio_base.gd` | `GameAudioBase` | Agrupa `AudioStreamPlayer` hijos por prefijo. `play(prefijo)`, `play_aleatorio(prefijo)`, respeta `sfx_enabled`. |
| `scripts/panel_resultados.gd` | `PanelResultados` | `mostrar(nivel_id,puntaje,max,id_game)` → umbrales 1/3, 2/3, 3/3 → ribbons, llama `save_manager.registrar_puntaje_nivel()`. Botones OK/Reiniciar. Señales `reiniciar_solicitado` / `continuar_solicitado`. |
| `scripts/carousel_menu.gd` | `CarouselMenu` | Carrusel cilíndrico del hub, drag+inercia+snap, `spin_intro`, auto-rotación tras 2s ocioso. |
| `scripts/panel_pausa.gd` | `PanelPausa` | Pausa dentro de partida, toggles música/SFX + BotonHome. |
| `scripts/ui_puntaje.gd` | `UIPuntaje` | `establecer_puntaje(int)` / `establecer_maximo(int)`. Escena `scenes/ui_puntaje.tscn`. |
| `scripts/ui_timer.gd` | `UITimer` | Countdown, signal `tiempo_agotado`. Escena `scenes/ui_timer.tscn`. |
| `scripts/ui_level_number.gd` | `UILevelNumber` | `establecer_nivel(int)`. Escena `scenes/ui_level_number.tscn`. |

### 3.3 Pantallas / escenas compartidas (`scenes/`)

| Escena | Script | Reutilización |
|---|---|---|
| `scenes/title.tscn` | `scripts/title.gd` | Hub con carrusel dinámico desde `data/games.json` (hoy solo plinko). Selección → `seleccion_niveles.tscn`. Prizes → `premios.tscn`, Options → `options.tscn`. |
| `scenes/seleccion_niveles.tscn` | `scripts/seleccion_niveles.gd` | Genérica, data-driven. Lee `games.json`, cuenta niveles, fondo dinámico por hora, pagina 9/pág, tap slot → `main.tscn`. |
| `scenes/slot_nivel.tscn` | `scripts/slot_nivel.gd` | Slot individual, bloqueado/desbloqueado con ribbons. |
| `scenes/panel_resultados.tscn` | `scripts/panel_resultados.gd` | Panel fin de nivel. |
| `scenes/puntos_flotantes.tscn` | — | Usado por `EfectosUI.crear_efecto_puntos()`. |
| `scenes/options.tscn` | `scripts/options.gd` | Toggles música/SFX + selector idioma. |
| `scenes/premios.tscn` | `scripts/premios.gd` | Galería de 18 premios. |
| `scenes/premio_desbloqueado.tscn` | `scripts/premio_desbloqueado.gd` | Celebración de premio nuevo. |
| `scenes/audio_manager.tscn` | `scripts/audio_manager.gd` | Contenedor de SFX del core (ok/welldone/prize/pop/fail). |
| `scenes/panel_pausa.tscn` | `scripts/panel_pausa.gd` | Pausa en partida. |
| `scenes/austral_animated_logo.tscn` | `scripts/austral_animated_logo.gd` | Splash/animación de logo. |

### 3.4 Shaders (`shaders/`)

| Shader | Uso |
|---|---|
| `shaders/desenfoque.gdshader` | Blur + oscurecer de `PanelResultados`. |
| `shaders/chromatic_aberration.gdshader` | Efecto cromático `CanvasItem`. |
| `shaders/crt_effect.gdshader` | CRT + scanlines (logo animado). |
| `shaders/logo_dissolver.gshader.gdshader` | Dissolve del logo splash. |

### 3.5 Assets (`assets/`)

- **Fonts** (`assets/fonts/`): `carnivalee_freakshow.ttf` (títulos/HUD), `evereast.ttf` (título de nivel), `PressStart2P-Regular.ttf` (logo animado).
- **UI kit** (`assets/images/ui/`): paneles, botones (ok/restart/home/gen/prizes/options/arrow/pause), iconos, ribbons, `shelve.webp`.
- **Premios** (`assets/images/prizes/`): 18 PNG (`aros`, `dino`, `drum`, `doll`, `roboto`, `duck`, `racer`, `tricep`, `horse`, `bunny`, `plane`, `train`, `rocket`, `robot`, `teddy`, `bluey`, `astro`, `rex`).
- **Fondos/logos** (`assets/images/`): `fondodia.webp`, `fondotarde.webp`, `fondonoche.webp`, `logo.webp`, `logoaustral.webp`.
- **Plinko** (`assets/`): `images/floor.webp`, `images/world/fondo_interior.webp`, `images/plinko_logo.webp` (renombrado de `logo.webp` por colisión con el del core), `models/board.glb`, `sounds/pik1.wav`, `pik2.wav`, `points.wav`.
- **SFX / temas** (`assets/sounds/`): `ok/ok1/ok2/fail/pop/welldone/prize/levelcomplete/…` + `themes/main_theme.ogg` y `themes/plinko.ogg` (se eliminaron los temas de juegos ya inexistentes: tincanalley, whackamole, ringtoss, duckshoot, credits).

---

## 4) Registro del juego — `data/games.json`

Solo entra plinko:

```json
{
	"plinko": {
		"escena_juego": "res://scenes/main.tscn",
		"ruta_niveles_json": "res://data/niveles.json",
		"textos_json": "res://data/plinko_textos.json",
		"textura_logo": "res://assets/images/plinko_logo.webp",
		"prefijo_texto": "plinko_"
	}
}
```

Campos: `escena_juego`, `ruta_niveles_json`, `textos_json`, `textura_logo` (`.webp`), `prefijo_texto`. El fondo de `seleccion_niveles` es dinámico por hora (`FondoDinamico`), no sale del registry.

---

## 5) Plinko — datos y escenas del juego

- `data/niveles.json`: `{"1": {"puntaje":450, "color_board":"EB051B", "pegs":[{x,y}…], "ramps":[{x,y,rot}…], "slots":[{x_start,x_end,pts,color}…]}}`. Claves `"1".."N"` contiguas.
- `data/plinko_textos.json`: títulos de nivel con prefijo `plinko_` gestionado por `game_manager`.
- `scenes/main.tscn`: escena jugable de plinko (board, pegs, ramps, slots, bola, cámara, UI). Usa `scenes/plinko_audio_manager.tscn` para SFX propios (`pik1`, `pik2`, `points`).
- `scripts/main.gd`: contrato con el core — lee `save_manager.nivel_actual_seleccionado`, expone `puntaje_nivel`/`puntaje_maximo_nivel`, incrusta `PanelResultados`, usa `ControladorResultados` y `EfectosUI.crear_efecto_puntos()`.

Scripts propios de plinko (en `scripts/`): `main.gd`, `ball.gd`, `board_frame.gd`, `color_utils.gd`, `peg.gd`, `ramp.gd`, `slot.gd`, `plinko_audio_manager.gd` (renombrado de `audio_manager.gd` para no colisionar con el autoload del core).

---

## 6) Skeleton `main.gd` — patrón del juego

Patrón consolidado (plinko `scripts/main.gd`):

```gdscript
extends Node3D

const MAX_BALLS: int = 5

@export_file("*.json") var ruta_niveles_json: String = "res://data/niveles.json"
@export var board_frame_scene: PackedScene = preload("res://scenes/board_frame.tscn")
@export var peg_scene: PackedScene = preload("res://scenes/peg.tscn")
@export var ramp_scene: PackedScene = preload("res://scenes/ramp.tscn")
@export var slot_scene: PackedScene = preload("res://scenes/slot.tscn")
@export var divider_scene: PackedScene = preload("res://scenes/divider.tscn")

@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego
@onready var boton_pausa: TextureButton = $UI/BotonPausa
@onready var panel_pausa: PanelPausa = $UI/PanelPausa as PanelPausa

var nivel_actual: int = 1
var puntaje_nivel: int = 0
var puntaje_maximo_nivel: int = 0
var ctrl_resultados: ControladorResultados

func _ready() -> void:
  nivel_actual = save_manager.nivel_actual_seleccionado
  ctrl_resultados = ControladorResultados.new()
  add_child(ctrl_resultados)
  ctrl_resultados.configurar(panel_resultados, [ui_puntaje, ui_level_number, boton_pausa], ui_puntaje, ui_level_number, reiniciar_nivel)
  cargar_nivel(nivel_actual)

func cargar_nivel(n: int) -> void:
  ctrl_resultados.reset()
  puntaje_nivel = 0
  puntaje_maximo_nivel = _leer_max_de_json(n)
  ctrl_resultados.actualizar_puntaje(puntaje_nivel)
  ctrl_resultados.actualizar_nivel(n)

func _on_puntos_ganados(pts: int, pos3d: Vector3) -> void:
  puntaje_nivel += pts
  ctrl_resultados.actualizar_puntaje(puntaje_nivel)
  EfectosUI.crear_efecto_puntos(pos3d, pts)
  if audio_juego: audio_juego.play_points()

func mostrar_panel_resultados() -> void:
  ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)

func reiniciar_nivel() -> void:
  cargar_nivel(nivel_actual)
```

---

## 7) Progresión, premios y localización

- **Desbloqueo de nivel:** `n` desbloqueado si `score(n-1)/max(n-1) >= 1/3`. Nivel 1 siempre desbloqueado.
- **Ribbons:** amarilla ≥1/3, roja ≥2/3, azul = 100% (`score >= max`).
- **Meta del nivel:** `puntaje_maximo` ≈ 60% del puntaje perfecto.
- **Premios globales:** `azules = contar_ribbons_azules()`; `total_niveles = obtener_total_niveles_game("plinko")`; para premio `i`: `requeridas = ceil(i * total_niveles / 18)`.
- **Localización:** `data/textos.json` (core, sin prefijo) + `data/plinko_textos.json` (prefijo `plinko_`). `obtener_texto` con fallback `es`. `obtener_titulo_nivel("3")` → busca `"plinko_3"`.
- **Audio prefs:** `audio_manager` persiste `music_enabled/sfx_enabled` en `save_manager`.

---

## 8) Estructura de archivos (actual)

```
.
├── project.godot              # autoloads (UID), viewport 720×1280, Jolt, main_scene title.tscn
├── export_presets.cfg
├── data/
│   ├── games.json             ← registry (único punto de registro, solo plinko)
│   ├── textos.json            ← {seleccion_nivel, nuevo_premio, pausa} es/en/pt
│   ├── plinko_textos.json     ← títulos de nivel de plinko (prefijo plinko_)
│   └── niveles.json           ← niveles de plinko
├── scripts/                   # autoloads + controladores + scripts de plinko
│   ├── save_manager.gd / game_manager.gd / audio_manager.gd / efectos_ui.gd
│   ├── controlador_resultados.gd / game_audio_base.gd / panel_resultados.gd
│   ├── title.gd / seleccion_niveles.gd / slot_nivel.gd / carousel_menu.gd
│   ├── ui_puntaje/timer/level_number.gd / options.gd / premios*.gd / panel_pausa.gd
│   ├── fondo_dinamico.gd / label.gd / logo_script.gd / austral_animated_logo.gd
│   ├── inappupdate.gd
│   └── plinko/: main.gd, ball.gd, board_frame.gd, color_utils.gd, peg.gd, ramp.gd, slot.gd, plinko_audio_manager.gd
├── scenes/                    # todas las pantallas
│   ├── title.tscn / seleccion_niveles.tscn / slot_nivel.tscn / panel_resultados.tscn
│   ├── puntos_flotantes.tscn / ui_puntaje/timer/level_number.tscn
│   ├── options.tscn / premios.tscn / premio_desbloqueado.tscn / audio_manager.tscn
│   ├── panel_pausa.tscn / austral_animated_logo.tscn / InAppUpdate.tscn
│   └── plinko/: main.tscn, ball.tscn, board_frame.tscn, divider.tscn, peg.tscn, ramp.tscn, slot.tscn, plinko_audio_manager.tscn
├── shaders/                   # desenfoque, chromatic_aberration, crt_effect, logo_dissolver
├── assets/
│   ├── fonts/                 # carnivalee_freakshow.ttf, evereast.ttf, PressStart2P-Regular.ttf
│   ├── images/
│   │   ├── ui/                # botones, iconos, ribbons, paneles, shelve
│   │   ├── prizes/            # 18 PNG de premios
│   │   ├── fondodia/tarde/noche.webp, logo.webp, logoaustral.webp
│   │   ├── plinko_logo.webp   # logo del tablero de plinko (renombrado)
│   │   ├── floor.webp, world/fondo_interior.webp
│   │   └── models/board.glb   # tablero 3D de plinko
│   └── sounds/
│       ├── *.wav (SFX del core)
│       └── themes/            # main_theme.ogg, plinko.ogg
└── skill.md
```

---

## 9) Flujo de navegación (código)

```gdscript
# title.gd — selección del único juego
save_manager.juego_actual_seleccionado = "plinko"
get_tree().change_scene_to_file("res://scenes/seleccion_niveles.tscn")

# seleccion_niveles.gd — lee games.json, fondo/logo, cuenta niveles
var cfg = game_manager.obtener_config_juego_actual() # {escena_juego, ruta_niveles_json, textura_logo, ...}
save_manager.nivel_actual_seleccionado = numero_nivel
get_tree().change_scene_to_file(cfg["escena_juego"])   # res://scenes/main.tscn

# scenes/main.tscn (plinko) — carga nivel, juega, termina
ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)
# → panel_resultados.gd: save_manager.registrar_puntaje_nivel(...) → ribbons + premio?
# → OK → premio_desbloqueado.tscn (si hay premio) o seleccion_niveles.tscn
```

---

## 10) Qué NO hacer

- No uses `res://core/` ni `res://games/` — ya no existen; usa `res://scripts/`, `res://scenes/`, `res://data/`, `res://assets/`.
- No hardcodees `id` de juego — usa `save_manager.juego_actual_seleccionado` (siempre `"plinko"`).
- No dupliques lógica de ribbons/desbloqueo — usa `save_manager` y `panel_resultados`.
- No instancies `puntos_flotantes.tscn` directo — usa `EfectosUI.crear_efecto_puntos(pos3D, pts)`.
- No añadas `AudioStreamPlayer` sueltos sin `GameAudioBase` — pierdes respeto a `sfx_enabled`.
- No olvides `prefijo_texto` (`plinko_`) — sin él los textos colisionan.
- Todo botón UI del core suena `audio_manager.play_ok1()` (click).

---

## 11) Running

Abrir la raíz en **Godot 4.7+** → Run (main scene = `title.tscn`). Export vía `Project → Export` (presets Web/iOS en `export_presets.cfg`).

---

*Última actualización: 2026-10-27 — un juego (plinko), arquitectura unificada en raíz, eliminadas carpetas `core/` y `games/` y los 4 juegos previos (tincanalley, whackamole, ringtoss, duckshoot), unificados scripts/scenes/data/assets/shaders en raíz. Convención: metas de nivel al 60% del perfecto; click único `play_ok1()` en botones UI.*
