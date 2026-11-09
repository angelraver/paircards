extends Node2D
## Crisp Juice Particles - 2D showcase: every effect in crisp_juice_fx/fx2d, auto-playing in a labelled grid.
## Click a cell to replay it.  Space: replay all.  B: light / dark background.  C: cycle recolor.  Tab: 3D showcase.

const FX_DIR := "res://crisp_juice_fx/fx2d"
const COLS := 7
const CELL := Vector2(268, 162)
const ORIGIN := Vector2(23, 92)
const HUES := [Color(0, 0, 0, 0), Color(1.0, 0.3, 0.35), Color(0.3, 0.85, 0.45), Color(0.3, 0.6, 1.0), Color(0.7, 0.4, 1.0)]
const SYNC := 1.2

var _cells: Array = []
var _t := 0.0
var _dark := true
var _hue := 0
@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Title
@onready var _hint: Label = $Hint


func _ready() -> void:
	var paths: Array = []
	for cat in DirAccess.get_directories_at(FX_DIR):
		for f in DirAccess.get_files_at(FX_DIR.path_join(cat)):
			var clean := f.trim_suffix(".remap")
			if clean.ends_with(".tscn"):
				paths.append(FX_DIR.path_join(cat).path_join(clean))
	paths.sort_custom(_by_category)
	for i in paths.size():
		_make_cell(i, paths[i])
	_title.text = "Crisp Juice Particles  -  %d real-time 2D effects" % paths.size()


func _by_category(a: String, b: String) -> bool:
	var order := ["combat", "rewards", "magic", "elements", "movement", "weather"]
	var ca := order.find(a.get_base_dir().get_file())
	var cb := order.find(b.get_base_dir().get_file())
	return a < b if ca == cb else ca < cb


func _make_cell(i: int, path: String) -> void:
	var rect := Rect2(ORIGIN + Vector2(i % COLS, i / COLS) * CELL, CELL - Vector2(8, 8))
	var tint := ColorRect.new()  # the faint cell background
	tint.position = rect.position
	tint.size = rect.size
	tint.color = Color(1, 1, 1, 0.045)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	var panel := ColorRect.new()  # invisible, opaque mask: keeps each effect inside its cell
	panel.position = rect.position
	panel.size = rect.size
	panel.color = Color.WHITE
	panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var fx: CrispFx2D = load(path).instantiate()
	fx.free_on_finish = false
	var view: float = fx.get_meta("view", 2.0)
	var area := Vector2(rect.size.x - 14.0, rect.size.y - 34.0)
	var mid := Vector2(rect.size.x * 0.5, 6.0 + area.y * 0.5)
	var s := minf(area.x, area.y) / (view * 100.0) * 1.08
	var holder := Node2D.new()
	holder.position = mid + Vector2(0, float(fx.get_meta("frame_y", 0.0)) * 100.0 * s)
	if fx.has_meta("bounds2d"):  # measured from real renders: fit what the effect actually draws into the cell
		var b: Array = fx.get_meta("bounds2d")
		var bs := Vector2(maxf(float(b[2]) - float(b[0]), 1.0), maxf(float(b[3]) - float(b[1]), 1.0))
		s = minf(minf(area.x / bs.x, area.y / bs.y), s * 1.45)
		holder.position = mid - Vector2((float(b[0]) + float(b[2])) * 0.5, (float(b[1]) + float(b[3])) * 0.5) * s
	fx.fx_scale = s
	if fx.has_meta("showcase_boost"):  # showcase only: ambient effects get bigger / denser particles so they read in a small cell
		var boost: Array = fx.get_meta("showcase_boost")
		for p in fx.get_children():
			if p is GPUParticles2D:
				var pm := (p.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
				pm.scale_min *= float(boost[0])
				pm.scale_max *= float(boost[0])
				p.process_material = pm
				p.amount = int(p.amount * float(boost[1]))
	panel.add_child(holder)
	holder.add_child(fx)
	var label := Label.new()
	label.text = path.get_file().get_basename().trim_suffix("_2d").replace("_", " ")
	label.position = Vector2(8, rect.size.y - 24)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.95, 0.94, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.12))
	label.add_theme_constant_override("outline_size", 5)
	panel.add_child(label)
	fx.autoplay = false
	# first play is timed so every one-shot hits its best moment together at SYNC seconds (then they loop freely)
	var first := maxf(0.0, SYNC - float(fx.get_meta("best_t", 0.0))) if not fx._looping else 0.0
	_cells.append({"fx": fx, "rect": rect, "idle": 0.0, "motion": fx.get_meta("demo_motion", ""), "view": view * s, "s": s,
		"first": first, "started": false})


func _process(delta: float) -> void:
	_t += delta
	for c in _cells:
		var fx: CrispFx2D = c["fx"]
		if c["motion"] != "":
			var m := motion(c["motion"], _t + 0.25, float(c["view"]))
			fx.position = Vector2(m.x, m.y) * 100.0
		if not c["started"]:
			if _t >= float(c["first"]):
				c["started"] = true
				fx.play()
			continue
		if not fx.is_playing():
			c["idle"] += delta
			if c["idle"] > 0.6:
				c["idle"] = 0.0
				fx.play()


## Demo movement for the trail effects (metres, y up). "dash" = quick back-and-forth dashes, else a loop.
static func motion(kind: String, t: float, view: float) -> Vector2:
	if kind == "dash":
		return Vector2(view * 0.32 * clampf(1.7 * sin(t * 2.4), -1.0, 1.0), 0.0)
	var a := t * 3.4
	return Vector2(cos(a), -sin(a) * 0.55) * view * 0.28


## Light (cream / sky) or dark background.
func set_dark(dark: bool) -> void:
	_dark = dark
	var m := _bg.material as ShaderMaterial
	m.set_shader_parameter("top", Color(0.09, 0.08, 0.17) if _dark else Color(0.78, 0.9, 1.0))
	m.set_shader_parameter("bottom", Color(0.16, 0.13, 0.28) if _dark else Color(1.0, 0.95, 0.86))
	var fg := Color(0.95, 0.94, 1.0) if _dark else Color(0.2, 0.17, 0.32)
	_title.add_theme_color_override("font_color", fg)
	_hint.add_theme_color_override("font_color", fg)


func light() -> void:
	set_dark(false)


## Step every effect to the next recolor in HUES (the first entry = original colours).
func cycle_recolor() -> void:
	_hue = (_hue + 1) % HUES.size()
	for c in _cells:
		c["fx"].recolor = HUES[_hue]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for c in _cells:
			if (c["rect"] as Rect2).has_point(get_local_mouse_position()):
				c["fx"].play()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				for c in _cells:
					c["fx"].play()
			KEY_B:
				set_dark(not _dark)
			KEY_C:
				cycle_recolor()
			KEY_TAB:
				get_tree().change_scene_to_file("res://crisp_juice_fx/showcase/showcase_3d.tscn")
