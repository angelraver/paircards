extends Node3D
## Crisp Juice Particles - 3D showcase: every effect in crisp_juice_fx/fx3d, in labelled rows by category.
## Up / Down (or wait): next row.  Space: replay all.  B: day / night.  C: cycle recolor.  Tab: 2D showcase.

const FX_DIR := "res://crisp_juice_fx/fx3d"
const ROW_GAP := 9.0
const HUES := [Color(0, 0, 0, 0), Color(1.0, 0.3, 0.35), Color(0.3, 0.85, 0.45), Color(0.3, 0.6, 1.0), Color(0.7, 0.4, 1.0)]

@export var auto_advance := 7.0
const SYNC := 1.2

var _cells: Array = []
var _rows: Array = []  # {z, width, title, height}
var _row := 0
var _t := 0.0
var _since := 0.0
var _day := false
var _hue := 0
@onready var _cam: Camera3D = $Camera
@onready var _env: WorldEnvironment = $Env
@onready var _sun: DirectionalLight3D = $Sun
@onready var _label: Label = $UI/Row


func _ready() -> void:
	var by_cat := {}
	var order := ["combat", "rewards", "magic", "elements", "movement", "weather"]
	for cat in DirAccess.get_directories_at(FX_DIR):
		for f in DirAccess.get_files_at(FX_DIR.path_join(cat)):
			var clean := f.trim_suffix(".remap")
			if clean.ends_with(".tscn"):
				if not by_cat.has(cat):
					by_cat[cat] = []
				by_cat[cat].append(FX_DIR.path_join(cat).path_join(clean))
	var z := 0.0
	for cat in order:
		if not by_cat.has(cat):
			continue
		var list: Array = by_cat[cat]
		list.sort()
		var per := 3 if cat == "weather" else 5
		var i := 0
		while i < list.size():
			var chunk := list.slice(i, i + per)
			_make_row(cat, chunk, z)
			z -= ROW_GAP if cat != "weather" else ROW_GAP * 1.4
			i += per
	_go(0, true)


func _make_row(cat: String, paths: Array, z: float) -> void:
	var fxs: Array = []
	var spacing := 3.6
	for p in paths:
		var fx: CrispFx3D = load(p).instantiate()
		fx.free_on_finish = false
		fxs.append(fx)
		spacing = maxf(spacing, minf(fx.get_meta("view", 2.0), 7.0) * 0.95 + 0.5)
	var n := fxs.size()
	var height := 1.0
	for j in n:
		var fx: CrispFx3D = fxs[j]
		var x := (j - (n - 1) * 0.5) * spacing
		var view: float = fx.get_meta("view", 2.0)
		if view > spacing:
			fx.fx_scale = spacing / view
		var holder := Node3D.new()
		holder.position = Vector3(x, float(fx.get_meta("demo_y", 0.0)) * fx.fx_scale, z)
		add_child(holder)
		holder.add_child(fx)
		height = maxf(height, float(fx.get_meta("demo_y", 0.0)) + 0.5)
		var label := Label3D.new()
		label.text = p_name(fx)
		label.font_size = 64
		label.pixel_size = 0.004
		label.outline_size = 26
		label.modulate = Color(0.98, 0.97, 1.0)
		label.outline_modulate = Color(0.07, 0.05, 0.15)
		label.position = Vector3(x, 0.12, z + 1.25)
		label.rotation_degrees = Vector3(-50, 0, 0)
		add_child(label)
		fx.autoplay = false
		var first := maxf(0.0, SYNC - float(fx.get_meta("best_t", 0.0))) if not fx._looping else 0.0
		_cells.append({"fx": fx, "idle": 0.0, "motion": fx.get_meta("demo_motion", ""), "view": view * fx.fx_scale, "holder": holder,
			"first": first, "started": false})
	_rows.append({"z": z, "width": n * spacing, "title": cat, "height": height})


func p_name(fx: Node) -> String:
	return fx.scene_file_path.get_file().get_basename().trim_suffix("_3d").replace("_", " ")


func _go(i: int, snap := false) -> void:
	_row = wrapi(i, 0, _rows.size())
	_since = 0.0
	var r: Dictionary = _rows[_row]
	_label.text = "%s   (row %d / %d)" % [String(r["title"]).capitalize(), _row + 1, _rows.size()]
	if snap:
		_cam.position = _cam_pos(r)
		_cam.look_at(_cam_target(r))


func _cam_target(r: Dictionary) -> Vector3:
	return Vector3(0, minf(float(r["height"]), 2.2) * 0.5 + 0.3, float(r["z"]) - 1.8)


func _cam_pos(r: Dictionary) -> Vector3:
	var w: float = maxf(float(r["width"]), 15.0)
	var hfov := 2.0 * atan(tan(deg_to_rad(_cam.fov) * 0.5) * 16.0 / 9.0)
	var d := (w * 0.5) / tan(hfov * 0.5) * 1.22
	return _cam_target(r) + Vector3(0, d * 0.36, d * 0.93)


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	if auto_advance > 0.0 and _since > auto_advance:
		_go(_row + 1)
	var r: Dictionary = _rows[_row]
	var k := 1.0 - exp(-delta * 3.0)
	_cam.position = _cam.position.lerp(_cam_pos(r), k)
	var fwd := -_cam.global_transform.basis.z
	var want := (_cam_target(r) - _cam.position).normalized()
	_cam.look_at(_cam.position + fwd.lerp(want, k).normalized())
	for c in _cells:
		var fx: CrispFx3D = c["fx"]
		if c["motion"] != "":
			var m := _motion(c["motion"], _t + 0.25, float(c["view"]))
			fx.position = Vector3(m.x, 0.0, -m.y * 1.1)
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_DOWN, KEY_S, KEY_RIGHT:
				_go(_row + 1)
			KEY_UP, KEY_W, KEY_LEFT:
				_go(_row - 1)
			KEY_SPACE:
				for c in _cells:
					c["fx"].play()
			KEY_B:
				set_day(not _day)
			KEY_C:
				_hue = (_hue + 1) % HUES.size()
				for c in _cells:
					c["fx"].recolor = HUES[_hue]
			KEY_TAB:
				get_tree().change_scene_to_file("res://crisp_juice_fx/showcase/showcase_2d.tscn")


static func _motion(kind: String, t: float, view: float) -> Vector2:
	if kind == "dash":
		return Vector2(view * 0.32 * clampf(1.7 * sin(t * 2.4), -1.0, 1.0), 0.0)
	var a := t * 3.4
	return Vector2(cos(a), -sin(a) * 0.55) * view * 0.28


## Jump the camera straight to row i (and stop the auto tour).
func show_row(i: Variant) -> void:
	auto_advance = 0.0
	_go(int(i), true)


func day() -> void:
	set_day(true)


func set_day(day: bool) -> void:
	_day = day
	var sky := (_env.environment.sky.sky_material as ProceduralSkyMaterial)
	if day:
		sky.sky_top_color = Color(0.35, 0.6, 0.95)
		sky.sky_horizon_color = Color(0.85, 0.9, 1.0)
		sky.ground_horizon_color = Color(0.85, 0.9, 1.0)
		_sun.light_energy = 1.2
		_env.environment.ambient_light_energy = 1.0
		($Ground.get_surface_override_material(0) as StandardMaterial3D).albedo_color = Color(0.5, 0.66, 0.46)
	else:
		sky.sky_top_color = Color(0.06, 0.05, 0.16)
		sky.sky_horizon_color = Color(0.27, 0.2, 0.42)
		sky.ground_horizon_color = Color(0.27, 0.2, 0.42)
		_sun.light_energy = 0.45
		_env.environment.ambient_light_energy = 0.6
		($Ground.get_surface_override_material(0) as StandardMaterial3D).albedo_color = Color(0.36, 0.42, 0.52)
