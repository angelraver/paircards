class_name CrispTrail2D
extends Line2D
## A fading ribbon behind a moving node (used by dash_trail, magic_missile...). Keep it as a child of the effect:
## it records the parent's global position every frame. Points live for [member length] seconds.

## Seconds of history kept in the trail.
@export var length := 0.25
## Add a new point once the head has moved this far (pixels).
@export var min_distance := 3.0
## Turn off to let the trail shrink away (the effect's stop() does this for you).
@export var emitting := true
## Offset from the parent's origin, in the parent's space.
@export var offset := Vector2.ZERO
## A jump longer than this in one frame (pixels) clears the trail instead of drawing a line across (teleports).
@export var max_jump := 400.0

var _pts: Array = []  # [Vector2, time]
var _time := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	clear_points()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var p: Vector2 = parent.global_position + offset.rotated(parent.global_rotation)
	if not _pts.is_empty() and (_pts[0][0] as Vector2).distance_to(p) > max_jump:
		_pts.clear()
	if emitting and parent.visible:
		if _pts.size() < 2 or (_pts[1][0] as Vector2).distance_to(p) >= min_distance:
			_pts.push_front([p, _time])
		else:
			_pts[0] = [p, _time]
	while _pts.size() > 0 and _time - _pts[-1][1] > length:
		_pts.pop_back()
	var arr := PackedVector2Array()
	for q in _pts:
		arr.append(q[0])
	points = arr if arr.size() > 1 else PackedVector2Array()
