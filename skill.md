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
| `game_manager` | `scripts/game_manager.gd` | Config/localización. Carga `data/games.json`, gestiona idioma (`idioma_actual`, `idioma_cambiado`), carga textos globales y por juego, `obtener_texto`, `obtener_titulo_nivel`, `obtener_config_juego_actual`, `obtener_score_nivel`. |
| `EfectosUI` | autoload configurado en proyecto | Autoload de efectos UI (configurado por UID en `project.godot`). |
| `InAppUpdate` | autoload configurado en proyecto | Autoload de actualización in-app (configurado por UID). |

## 4. Navegación y escenas (`scenes/`)

| Escena | Script | Rol |
|--------|--------|-----|
| `title.tscn` | `title.gd` | Hub inicial/carrusel y acceso a juegos, premios y opciones. |
| `seleccion_niveles.tscn` | `seleccion_niveles.gd` | Selector de niveles data-driven: lee `ruta_niveles_json` de `games.json` y construye las secuencias desde las claves numéricas de `niveles.json`. |
| `slot_nivel.tscn` | `slot_nivel.gd` | Slot de nivel (bloqueado/desbloqueado) con `moneda1`..`moneda3` según `hi` guardado vs `score` del nivel. |
| `main.tscn` | `main.gd` | Partida: tablero 3D, barra, HUD, pausa y resultados. |
| `panel_pausa.tscn` | `panel_pausa.gd` | Pausa en partida (toggles música/SFX, home). |
| `panel_resultados.tscn` | `panel_resultados.gd` | Fin de nivel; señal `reiniciar_solicitado`. `LabelPuntajeFinal` muestra `puntaje / score`; `moneda1`..`moneda3` según el mismo cálculo. OK navega a premio desbloqueado o selección de niveles. |
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
    "textos_json": "res://data/niveles_texto.json",
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
- `data/niveles_texto.json`: textos del juego (p.ej. títulos de nivel) cargados con `prefijo_texto` (`juego_`).

## 6. Sistema de niveles y armado del tablero (`scripts/main.gd` y auxiliares)

### Patrón de distribución (`patron`)
Define qué celdas axiales `(q,r)` existen en cada capa y el desplazamiento por capa para que las capas se intercalen. Se configura en `niveles.json` bajo `patron` y `_configurar_nivel` lo delega a `scripts/tablero_geometria.gd`.

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

**Centrado automático:** `TableroGeometria` calcula el centroide de las celdas crudas por capa y aplica un offset de centrado (`_patron_centro`) en `posicion_mundo`. Los círculos ya tienen centroide en (0,0) por su fórmula; los patrones explícitos quedan centrados en el origen sin desplazarse de pantalla.

### Funciones clave en `main.gd`
- `_cargar_json(ruta)`: lee y parsea un JSON de configuración.
- `_cargar_configuracion()`: carga `niveles.json` y `valores.json`.
- `_configurar_nivel(n)`: resuelve `capas`, `slots`, `fichas_n`, `fichas_t` para el nivel `n`, llena `_tipos_nivel`/`_fichas_config` y configura `TableroGeometria`.
- `_cargar_texturas()`: carga las texturas PNG de los tipos del nivel desde `assets/images/astronomia/`.
- `_preparar_reparto()`: calcula capacidad por capa mediante `TableroGeometria.capacidad_capa(capa)`, limita a `fichas_n` (par) quitando desde capas inferiores si hace falta.
- `_generar_fichas()`: genera parejas de tipos aleatorios, baraja y asigna a celdas aleatorias por capa usando `TableroGeometria.generar_celdas(capa)`.
- `_crear_ficha(tipo, capa, celda)`: instancia `assets/models/ficha.glb`, aplica shader y textura, coloca en el mundo y crea colisión cilíndrica.

### Detalles internos de `main.gd`
- `scripts/ficha_tablero.gd` (`FichaTablero`): nodo 3D con la malla del GLB, un `StaticBody3D` + `CylinderShape3D` y `set_meta("ficha", self)` para recuperarla desde el raycast. Guarda `tipo`, `capa`, `celda`, `textura`, `material`, `libre`.
- Texturas: se cargan una vez por nivel en `_texturas` y se aplican a la cara superior con `shaders/ficha_cara.gdshader`. Los iconos de la barra se renderizan en `SubViewport` con entorno transparente; las fichas acumuladas y sus placeholders usan `ESCALA_FICHAS_BARRA = 1.3`.
- `scripts/tablero_geometria.gd` (`TableroGeometria`): `RADIO_MAX_CAPA` se mide en diámetros de ficha; `DIAMETRO_FICHA = 0.132`, `GROSOR_FICHA = 0.022`, `SEPARACION_CAPAS = 0.026`, `SEPARACION_FICHAS == DIAMETRO_FICHA`. El intercalado es `(0.5, sqrt(3)/6)` (`DESPLAZAMIENTO_INTERCALADO`). El tablero se centra con `CENTRO_TABLERO`, `ALTURA_PISO = -0.04` y la barra 3D queda en `ALTURA_PISO + 0.002`.
- Colisión: las fichas usan `CAPA_COLISION_FICHAS = 2` (bit 2) para que el raycast no choque con el piso ni con otros objetos.
- Animaciones: entrada en cascada (`ALTURA_CAIDA_INICIAL = 4.0`, `DURACION_CAIDA = 0.7`, `ESCALON_CAIDA_POR_CAPA = 0.12`, `ESPACIO_ENTRE_FICHAS = 0.05`) con capas inferiores primero; selección con salto vertical corto y vuelo en arco con dos vueltas sobre X (`DURACION_VUELO = 1.1`).
- `scripts/efectos_partida.gd` (`EfectosPartida`): al resolver un combo instancia `smoke_puff_2d` en 2D sobre el slot y un `puntos_flotantes.tscn` con la etiqueta y el total.

### Posición en el mundo
`TableroGeometria.posicion_mundo(celda, capa)` convierte coordenadas axiales a plano XZ:
```
plano = (_axial_a_plano(celda) + _desplazamiento_capa(capa) + _patron_centro[capa-1]) * SEPARACION_FICHAS
```
donde `_axial_a_plano(q,r) = (q + r*0.5, r*sqrt(3)/2)` y `SEPARACION_FICHAS == DIAMETRO_FICHA` (vecinas se tocan).

### Visibilidad y selección
- **Libre:** `scripts/tablero_visibilidad.gd` (`TableroVisibilidad`) marca una ficha como seleccionable si ninguna ficha de capa superior (número de capa menor) se superpone en plano XZ (distancia entre centros < diámetro).
- **Feedback:** fichas bloqueadas se oscurecen según capa (`OSCURIDAD_BASE_CAPAS`).
- **Input:** tap/click → raycast (`CAPA_COLISION_FICHAS`) → selecciona ficha libre si no hay animación de entrada, pausa o panel de resultados.

### Barra inferior y combo
- **Barra:** renderizada como quad 3D sobre el piso (SubViewport + Sprite3D) con fondo/UI 2D y slots centrados (`HBoxContainer`, `ALIGNMENT_CENTER`). Cantidad de slots = `slots` del nivel (dinámico, 1..5).
- **Al seleccionar ficha libre:** vuela a la barra (salto + trayectoria en arco + rotación). Si su tipo ya existe en algún slot, se acumula en ese slot (reinicia ventana de combo de 2s al aterrizar y pasa a ser el slot activo). Si es tipo nuevo, ocupa un slot libre (o derrota si no hay libres). Slots con ficha en vuelo pueden ocultar icono hasta aterrizar.
- **Última ficha del tablero:** no se activa la ventana de combo. Si hay fichas iguales esperando en un slot, al aterrizar se suma a ellas y el grupo desaparece de inmediato (humo + valor del combo). Si no hay coincidencia, va a un slot libre y el nivel termina con esa ficha huérfana en la barra.
- **Ventana de combo:** `TIEMPO_COMBO = 2.0s`, se inicia/reinicia al aterrizar una ficha en el slot activo, salvo en la última ficha del tablero. Si expira con vuelo pendiente al slot activo, la resolución se difiere.
- **Resolución:**
  - Acumulación `>= 2` en el slot: desaparece al expirar la ventana sin nueva coincidencia o al romperse el combo por seleccionar otra cara; muestra humo y total de puntos.
  - Acumulación `1` (solitaria): permanece en su slot.
  - Cambiar de cara/foco rompe el combo activo previo (resolviéndolo según regla anterior).
- **Puntos flotantes:** instancia `scenes/puntos_flotantes.tscn` en capa de efectos; muestra `+N` al aterrizar una acumulación (`N = contador-1`) y, al resolverse el combo, `ETIQUETA` en una línea y `PUNTOS` en la siguiente.
- **Título en partida:** `scripts/titulo_partida.gd` (`TituloPartida`) rellena `$UI/LevelTitle` al cargar/reiniciar con `Nivel N\n<Título localizado>` usando `game_manager.obtener_titulo_nivel(...)`. Permanece 3s, se desvanece en 1s y luego se reutiliza para el mensaje breve de victoria/derrota.

### Fin de partida
- **Victoria:** tablero vacío, aunque queden fichas huérfanas en la barra.
- **Derrota:** se intenta colocar un tipo nuevo sin slot libre.
- Muestra mensaje breve y abre `panel_resultados` vía `ControladorResultados`.
- `panel_resultados.gd` rellena su `LevelTitle` con `N\n<Título localizado>` en el idioma vigente y lo refresca si cambia `idioma_cambiado`.

## 7. Audio

- **Global (`audio_manager.gd`):** controla BGM y SFX habilitados (persistidos), reproduce SFX comunes (`ok1`, `start`, `welldone`, `prize`, `pop`, `fail`) y gestiona temas BGM (`ensure_title_bgm`, `ensure_game_bgm`).
- **Partida (`main_audio.gd`, `class_name MainAudio`):** crea dinámicamente players para `drop1..drop4`, `select` y `selected` (`assets/sounds/`), agrupa por prefijo y expone `play_drop()`, `play_select()`, `play_selected()`. Respeta `audio_manager.sfx_enabled`.
- **Pausa:** `panel_pausa.gd` pausa el árbol (`SceneTree.paused`) sin cortar la música (BGM en `PROCESS_MODE_ALWAYS`).

## 8. Controladores y utilidades reutilizables

| Script | class_name | Uso |
|--------|------------|-----|
| `controlador_resultados.gd` | `ControladorResultados` | Orquesta `PanelResultados`: reset/mostrar, ocultar-restaurar HUD, conexión de reinicio, actualización de nivel. |
| `combo_puntos.gd` | `ComboPuntos` | Configuración y cálculo puro de combos: tabla +2..+10, base 100, ventana 2.0s, etiquetas y verificación de reglas. |
| `panel_resultados.gd` | `PanelResultados` | UI de fin de nivel, señal `reiniciar_solicitado`, navegación OK, cálculo de monedas y título localizado del nivel. |
| `panel_pausa.gd` | `PanelPausa` | Lógica de pausa. |
| `ui_level_number.gd` | `UILevelNumber` | Muestra número de nivel. |
| `ui_puntaje.gd` | `UIPuntaje` | Muestra puntaje actual, meta del nivel e hi-score (`establecer_*`). |
| `slot_nivel.gd` | `SlotNivel` (según escena/script) | Representación de nivel en selector; calcula monedas desde `save_manager.obtener_puntaje_nivel` y `game_manager.obtener_score_nivel`. |
| `fondo_dinamico.gd`, `logo_script.gd`, `label.gd` | — | Soporte visual/UI en pantallas. |

## 9. Progresión, ribbons y premios

- **Puntaje en partida:** `scripts/combo_puntos.gd` centraliza `BASE_PUNTOS_FICHA = 100`, `VENTANA_COMBO_SEG = 2.0` y `TABLA_COMBOS`. Al resolverse un combo en `_romper_combo()` se calcula `round(n * 100 * multiplicador)` y ese total se suma al puntaje global y aparece con el humo. Si `n > 10`, se mantienen el multiplicador y la etiqueta de `10`. `ui_puntaje.tscn` muestra el total en `Label`, `/ score` (de `niveles.json`) en `Max` y el `hi` guardado en `HiNumber` (`0` si no existe).

  | Combo | Multiplicador | Etiqueta | Puntos |
  |-------|---------------|----------|--------|
  | 2 | 1.0 | PAR | 200 |
  | 3 | 1.3 | TRÍO | 390 |
  | 4 | 1.7 | CUARTETO | 680 |
  | 5 | 2.2 | QUINTETO | 1100 |
  | 6 | 2.8 | SEXTETO | 1680 |
  | 7 | 3.5 | SÉPTIMO | 2450 |
  | 8 | 4.4 | OCTETO | 3520 |
  | 9 | 5.6 | NOVENO | 5040 |
  | 10 | 7.2 | ASTRAL +10 | 7200 |

  `ComboPuntos.verificar_reglas()` comprueba en debug que `2 => 200`, `10 => 7200` y que una espera mayor a `2.0s` deja la racha en `0`.
- **Resultado por nivel:** `LabelPuntajeFinal` muestra siempre `"puntaje / score"` (p. ej. `10 / 30`). Las monedas solo aparecen al superar el nivel: `moneda1` si `puntaje > score/3`, `moneda2` si `puntaje > 2*score/3`, `moneda3` si `puntaje >= score`. Son acumulativas; con `score <= 0` permanecen ocultas.
- **Monedas en el selector:** `slot_nivel.tscn` aplica la misma comparación usando el `hi` de `save_manager` para ese nivel. El `score` se obtiene con `game_manager.obtener_score_nivel(nivel)` desde `ruta_niveles_json`.
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
│   └── niveles_texto.json ← textos del juego (prefijo juego_)
├── scripts/
│   ├── main.gd                    # lógica principal: ciclo de vida, input, combo y coordinación
│   ├── ficha_tablero.gd           # nodo FichaTablero (malla, colisión, metadatos)
│   ├── tablero_geometria.gd       # patrones, celdas y posiciones del tablero
│   ├── tablero_visibilidad.gd     # solapamiento y oscurecido de fichas
│   ├── efectos_partida.gd         # humo y puntos flotantes
│   ├── titulo_partida.gd          # título localizado y mensajes breves
│   ├── combo_puntos.gd            # tabla de multiplicadores y cálculo de puntaje de combo
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

- La coordinación de la partida vive en `scripts/main.gd`; geometría, visibilidad, efectos y título están en los auxiliares listados arriba. Los parámetros de nivel vienen de `data/niveles.json` y el mapeo de tipos/texturas de `data/valores.json`. `main.gd` conserva solo encabezados de sección: las reglas explicadas están en las secciones 6 y 9.
- Para agregar/modificar niveles, mantener claves consistentes entre `fichas_t` (niveles) y `fichas` (valores) y asegurar textura en `assets/images/astronomia/`.
- `slots` en nivel controla la dificultad/capacidad de la barra (1..5) y la UI se adapta dinámicamente.
- `patron` en nivel controla la forma del tablero: `"circulos"` para variantes circulares rápidas, `"celdas"` (arrays axiales por paridad + offsets) como formato universal de mapa.
- Puntos flotantes en partida se crean instanciando `scenes/puntos_flotantes.tscn` desde `scripts/efectos_partida.gd`; SFX de la partida pasan por `main_audio` (`MainAudio`).
- Validar cambios en Godot 4.7 (no hay linter/typecheck de GDScript configurado en este entorno).
