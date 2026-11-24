class_name CrispTrail3D
extends MeshInstance3D
## A camera-facing ribbon behind a moving node (used by dash_trail, magic_missile...). Works in Forward+, Mobile
## and Compatibility (it is an ImmediateMesh, not a particle trail). Keep it as a child of the effect.

## Seconds of history kept in the trail.
@export var length := 0.25
## Add a new point once the head has moved this far (metres).
@export var min_distance := 0.04
## Offset from the parent's origin, in the parent's space.
@export var offset := Vector3.ZERO
## Turn off to let the trail shrink away.
@export var emitting := true
## A jump longer than this in one frame (metres) clears the trail instead of drawing a line across (teleports).
@export var max_jump := 4.0

var _pts: Array = []  # [Vector3, time]
var _time := 0.0
var _im := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _im
	extra_cull_margin = 4.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var p: Vector3 = parent.global_transform * offset
	if not _pts.is_empty() and (_pts[0][0] as Vector3).distance_to(p) > max_jump:
		_pts.clear()
	if emitting and parent.visible:
		if _pts.size() < 2 or (_pts[1][0] as Vector3).distance_to(p) >= min_distance:
			_pts.push_front([p, _time])
		else:
			_pts[0] = [p, _time]
	while _pts.size() > 0 and _time - _pts[-1][1] > length:
		_pts.pop_back()
	_im.clear_surfaces()
	var n := _pts.size()
	if n < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var a: Vector3 = _pts[maxi(i - 1, 0)][0]
		var b: Vector3 = _pts[mini(i + 1, n - 1)][0]
		var tangent := a - b
		if tangent.length_squared() < 1e-8:
			tangent = Vector3.RIGHT
		var k := clampf(float(i) / float(n - 1), 0.0, 1.0)
		for side in 2:
			_im.surface_set_normal(tangent.normalized())
			_im.surface_set_uv(Vector2(k, float(side)))
			_im.surface_add_vertex(_pts[i][0])
	_im.surface_end()
