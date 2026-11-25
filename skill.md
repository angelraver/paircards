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
| `save_manager` | `scripts/save_manager.gd` | Progreso y opciones en un solo juego: `levels` → `{ "1": { "hi": 0 } }`. Estado de sesión (`nivel_actual_seleccionado`, página de niveles). API: `registrar_puntaje_nivel`, `obtener_puntaje_nivel`, `es_nivel_desbloqueado`, `contar_ribbons_azules`, `obtener_total_niveles`, `guardar_a_disco`, opciones audio/idioma. |
| `audio_manager` | `scripts/audio_manager.gd` | BGM y SFX globales. `music_enabled`/`sfx_enabled`, `play_bgm`, `play_start/welldone/prize/ok1/pop/fail`, `ensure_title_bgm`, `ensure_game_bgm(id)`, cache de themes (`assets/sounds/themes/`). |
| `game_manager` | `scripts/game_manager.gd` | Config/localización. Carga `data/games.json`, gestiona idioma (`idioma_actual`, `idioma_cambiado`), carga textos globales y por juego, `obtener_texto`, `obtener_titulo_nivel`, `obtener_config_juego_actual`. |
| `EfectosUI` | autoload configurado en proyecto | Autoload de efectos UI (configurado por UID en `project.godot`). |
| `InAppUpdate` | autoload configurado en proyecto | Autoload de actualización in-app (configurado por UID). |

## 4. Navegación y escenas (`scenes/`)

| Escena | Script | Rol |
|--------|--------|-----|
| `title.tscn` | `title.gd` | Hub inicial/carrusel y acceso a juegos, premios y opciones. |
| `seleccion_niveles.tscn` | `seleccion_niveles.gd` | Selector de niveles data-driven: lee `ruta_niveles_json` de `games.json` y construye las secuencias desde las claves numéricas de `niveles.json`. |
| `slot_nivel.tscn` | `slot_nivel.gd` | Slot de nivel (estado bloqueado/desbloqueado, ribbons). |
| `main.tscn` | `main.gd` | Partida: tablero 3D, barra, HUD, pausa y resultados. |
| `panel_pausa.tscn` | `panel_pausa.gd` | Pausa en partida (toggles música/SFX, home). |
| `panel_resultados.tscn` | `panel_resultados.gd` | Fin de nivel; señal `reiniciar_solicitado`. OK navega a premio desbloqueado o selección de niveles. |
| `puntos_flotantes.tscn` | — | Label flotante animado usado para mostrar puntos en partida. |
| `ui_level_number.tscn` | `ui_level_number.gd` | Indicador de nivel (`establecer_nivel`). |
| `ui_puntaje.tscn` | `ui_puntaje.gd` | HUD de puntos: actual, `/ score` del nivel e `hi` guardado. |
| `options.tscn` | `options.gd` | Opciones (música, SFX, idioma). |
| `premios.tscn` | `premios.gd` | Galería de premios. |
| `premio_desbloqueado.tscn` | `premio_desbloqueado.gd` | Pantalla de premio desbloqueado. |
| `audio_manager.tscn` | `audio_manager.gd` | Contenedor/escena del audio global. |
| `main_audio.tscn` | `main_audio.gd` | Audio SFX específico de la partida (instancia en `main.tscn`). |
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
Definición por id de nivel (string). Campos usados por `scripts/main.gd`. El selector (`seleccion_niveles.gd`) cuenta las claves numéricas y solo expone niveles en umbrales `9`, `17`, `25`, ...: con 10..16 solo muestra 9, con 18..24 solo 17, con 25 muestra 25. Cada secuencia aporta 9 slots, pero comparte el primer slot con la anterior (8 nuevos por secuencia).

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `capas` | int | Número de capas del tablero (>=1). Capa 1 = superior. |
| `slots` | int | Cantidad de espacios en la barra inferior (1..5, centrados horizontalmente). |
| `score` | int | Puntaje base del nivel (actualmente `0` en todos). |
| `fichas_n` | int | Cantidad objetivo de fichas a colocar (se ajusta a par y al máximo posible por capacidad). |
| `fichas_t` | Array[str] | Claves de tipos permitidos para el nivel (mapeadas en `valores.json`). |
| `patron` | str\|dict | Patrón de distribución de fichas por capa. Ver sección 6. |

Ejemplo actual:
```json
{
  "1": { "capas": 3, "slots": 2, "score": 0, "fichas_n": 64, "fichas_t": ["a","b","c","d","e","f"],
         "patron": { "tipo": "circulos", "radio": 2.1,
                     "offset_impar": [0, 0], "offset_par": [0.5, 0.28867513459481287] } },
  "2": { "capas": 6, "slots": 3, "score": 0, "fichas_n": 60, "fichas_t": ["a","b","c","d","e","f","g"],
         "patron": { "tipo": "celdas",
                     "offset_impar": [0, 0], "offset_par": [0.5, 0.28867513459481287],
                     "celdas_impar": [[0,0],[-1,1],[0,1],[-2,2],[-1,2],[0,2],[-3,3],[-2,3],[-1,3],[0,3]],
                     "celdas_par": [[1,0],[0,1],[1,1],[-1,2],[0,2],[1,2],[-2,3],[-1,3],[0,3],[1,3]] } }
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

## 6. Sistema de niveles y armado del tablero (`scripts/main.gd`)

### Patrón de distribución (`patron`)
Define qué celdas axiales `(q,r)` existen en cada capa y el desplazamiento por capa para que las capas se intercalen. Se configura en `niveles.json` bajo `patron` y se lee en `_configurar_nivel`.

Formatos soportados:

**`"circulos"` (fórmula, simple para tamaños simétricos)**
```json
"patron": "circulos"
// o parametrizado:
"patron": { "tipo": "circulos", "radio": 2.1,
            "offset_impar": [0, 0], "offset_par": [0.5, 0.28867513459481287] }
```
Genera una grilla hexagonal recortada a un círculo de radio `R` (en diámetros) y aplica el intercalado triangular entre capas (impares centradas, pares desplazadas al hueco triangular).

**`"celdas"` (arrays explícitos, más simple y general para dibujar cualquier forma)**
```json
"patron": {
  "tipo": "celdas",
  "offset_impar": [0, 0],
  "offset_par": [0.5, 0.28867513459481287],
  "celdas_impar": [[q,r], ...],   // celdas de capas impares
  "celdas_par": [[q,r], ...]      // celdas de capas pares
}
```
Cada celda es `[q,r]` (o `{"q":..,"r":..}`). Se listan exactamente qué posiciones existen por paridad de capa. Es la forma más directa de “dibujar” disposiciones arbitrarias (triángulos, pirámides, cruces, formas raras) sin inventar fórmulas. Para mantener el intercalado/tapado parcial entre capas hay que usar el offset par al hueco triangular (`[0.5, sqrt(3)/6]`).

**Centrado automático:** el código calcula el centroide de las celdas crudas por capa y aplica un offset de centrado (`_patron_centro`) en `_posicion_mundo`. Los círculos ya tienen centroide en (0,0) por su fórmula; los patrones explícitos quedan centrados en el origen sin desplazarse de pantalla.

### Funciones clave en `main.gd`
- `_cargar_json(ruta)`: lee y parsea un JSON de configuración.
- `_cargar_configuracion()`: carga `niveles.json` y `valores.json`.
- `_configurar_nivel(n)`: resuelve `capas`, `slots`, `fichas_n`, `fichas_t`, `patron` para el nivel `n` y llena `_tipos_nivel`, `_fichas_config`, `_patron_*`.
- `_cargar_texturas()`: carga las texturas PNG de los tipos del nivel desde `assets/images/astronomia/`.
- `_preparar_reparto()`: calcula capacidad por capa mediante `_capacidad_capa(capa)`, limita a `fichas_n` (par) quitando desde capas inferiores si hace falta.
- `_generar_fichas()`: genera parejas de tipos aleatorios, baraja y asigna a celdas aleatorias por capa usando `_generar_celdas(capa)`.
- `_crear_ficha(tipo, capa, celda)`: instancia `assets/models/ficha.glb`, aplica shader y textura, coloca en el mundo y crea colisión cilíndrica.

### Posición en el mundo
`_posicion_mundo(celda, capa)` convierte coordenadas axiales a plano XZ:
```
plano = (_axial_a_plano(celda) + _desplazamiento_capa(capa) + _patron_centro[capa-1]) * SEPARACION_FICHAS
```
donde `_axial_a_plano(q,r) = (q + r*0.5, r*sqrt(3)/2)` y `SEPARACION_FICHAS == DIAMETRO_FICHA` (vecinas se tocan).

### Visibilidad y selección
- **Libre:** una ficha es seleccionable si ninguna ficha de capa superior (número de capa menor) se superpone en plano XZ (distancia entre centros < diámetro).
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

## 7. Audio

- **Global (`audio_manager.gd`):** controla BGM y SFX habilitados (persistidos), reproduce SFX comunes (`ok1`, `start`, `welldone`, `prize`, `pop`, `fail`) y gestiona temas BGM (`ensure_title_bgm`, `ensure_game_bgm`).
- **Partida (`main_audio.gd`, `class_name MainAudio`):** crea dinámicamente players para `drop1..drop4`, `select` y `selected` (`assets/sounds/`), agrupa por prefijo y expone `play_drop()`, `play_select()`, `play_selected()`. Respeta `audio_manager.sfx_enabled`.
- **Pausa:** `panel_pausa.gd` pausa el árbol (`SceneTree.paused`) sin cortar la música (BGM en `PROCESS_MODE_ALWAYS`).

## 8. Controladores y utilidades reutilizables

| Script | class_name | Uso |
|--------|------------|-----|
| `controlador_resultados.gd` | `ControladorResultados` | Orquesta `PanelResultados`: reset/mostrar, ocultar-restaurar HUD, conexión de reinicio, actualización de nivel. |
| `panel_resultados.gd` | `PanelResultados` | UI de fin de nivel, señal `reiniciar_solicitado`, navegación OK. |
| `panel_pausa.gd` | `PanelPausa` | Lógica de pausa. |
| `ui_level_number.gd` | `UILevelNumber` | Muestra número de nivel. |
| `ui_puntaje.gd` | `UIPuntaje` | Muestra puntaje actual, meta del nivel e hi-score (`establecer_*`). |
| `slot_nivel.gd` | `SlotNivel` (según escena/script) | Representación de nivel en selector. |
| `fondo_dinamico.gd`, `logo_script.gd`, `label.gd` | — | Soporte visual/UI en pantallas. |

## 9. Progresión, ribbons y premios

- **Puntaje en partida:** al cerrarse un combo con `n >= 2` fichas se suma `1+2+...+(n-1)` al puntaje global; ese mismo total es el número flotante que aparece con el humo. `ui_puntaje.tscn` muestra el total en `Label`, `/ score` (de `niveles.json`) en `Max` y el `hi` guardado en `HiNumber` (`0` si no existe).
- **Progreso por nivel:** `user://progreso.json` usa `levels` (sin `games`); cada nivel superado crea `"n": { "hi": max_puntos }`. Al mostrarse `panel_resultados` tras una victoria se llama a `save_manager.registrar_puntaje_nivel(nivel, puntos)`.
- **Desbloqueo:** nivel 1 siempre disponible; nivel `n` se desbloquea si existe el nodo `n-1` en `levels`.
- **Ribbons azules:** uno por nivel superado (nodo presente en `levels`), usado para el cálculo de premios.
- **Premios:** lista global de 18 premios; desbloqueo progresivo según ribbons azules/totales (cálculo en `save_manager`), con pantalla de premio desbloqueado cuando corresponde.

## 10. Estructura de archivos (resumen)

```
.
├── project.godot
├── export_presets.cfg
├── data/
│   ├── games.json
│   ├── niveles.json      ← definición de niveles y patrones
│   ├── valores.json      ← mapeo tipo → nombre de textura
│   ├── textos.json       ← textos globales es/en/pt
│   └── juego_textos.json ← textos del juego (prefijo juego_)
├── scripts/
│   ├── main.gd                    # lógica principal: generación de tablero, patrones, combo, barra
│   ├── main_audio.gd
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
│   ├── audio_manager.tscn, main_audio.tscn, ui_level_number.tscn
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
- `patron` en nivel controla la forma del tablero: `"circulos"` para variantes circulares rápidas, `"celdas"` (arrays axiales por paridad + offsets) como formato universal de mapa.
- Puntos flotantes en partida se crean instanciando `scenes/puntos_flotantes.tscn` desde `main.gd`; SFX de la partida pasan por `main_audio` (`MainAudio`).
- Validar cambios en Godot 4.7 (no hay linter/typecheck de GDScript configurado en este entorno).
