@tool
@icon("res://crisp_juice_fx/icon.svg")
class_name CrispFx3D
extends Node3D
## A Crisp Juice Particles effect (3D). Every scene in crisp_juice_fx/fx3d uses this script.
##
## Drop a scene into your level, or spawn one from code:
##[codeblock]
##const HIT := preload("res://crisp_juice_fx/fx3d/combat/hit_impact_3d.tscn")
##CrispFx3D.spawn(HIT, get_tree().current_scene, enemy.global_position)
##[/codeblock]
## One-shot effects play once, emit [signal finished] and free themselves (see [member free_on_finish]).
## Looping effects (fire, rain, portal...) play until [method stop].

## Emitted when a one-shot effect has completely finished.
signal finished

## Start playing as soon as the node enters the scene tree.
@export var autoplay := true
## One-shot effects: delete the node when it has finished. Turn off to keep the node and call play() again.
@export var free_on_finish := true
## Tint multiplied over the whole effect. White keeps the original colours.
@export var color := Color.WHITE:
	set(value):
		color = value
		_apply_color()
## Recolour: shifts the effect's hues so its main colour becomes this one, keeping white-hot cores, shading
## and darker accents. Leave fully transparent (alpha 0) for the original colours.
@export var recolor := Color(0, 0, 0, 0):
	set(value):
		recolor = value
		_apply_recolor()
## Size multiplier. Sets the node's scale.
@export_range(0.05, 8.0, 0.01, "or_greater") var fx_scale := 1.0:
	set(value):
		fx_scale = value
		scale = Vector3.ONE * value
## How many particles to emit, as a fraction of the designed amount (lower it for mobile or busy scenes).
@export_range(0.0, 1.0, 0.01) var amount := 1.0:
	set(value):
		amount = value
		_apply_amount()
## Playback speed of particles and animated shaders.
@export_range(0.05, 4.0, 0.01) var speed := 1.0:
	set(value):
		speed = value
		_apply_speed()
## Editor only: replay one-shot effects every couple of seconds so you can see them while you tweak.
@export var editor_preview := true

var _t := 0.0
var _playing := false
var _looping := false
var _length := 0.0
var _fade := 1.0
var _stopping := false
var _idle := 0.0
var _emitters: Array = []  # [GPUParticles, delay, started]
var _animated: Array = []  # [node, delay, duration, loop, hold, material]
var _lights: Array = []  # [OmniLight3D, mode, base_energy, delay, duration]
var _collected := false


func _ready() -> void:
	_collect()
	_apply_recolor()
	_apply_color()
	_apply_amount()
	_apply_speed()
	if Engine.is_editor_hint():
		if get_tree().edited_scene_root == self:
			return  # editing the effect itself: leave the nodes as authored
		if _looping:
			play()
		return
	for e in _emitters:
		if e[0].one_shot or not autoplay:
			e[0].emitting = false
	if autoplay:
		play()
	else:
		_hide_all()


## Restart the effect from the beginning.
func play() -> void:
	_collect()
	_t = 0.0
	_idle = 0.0
	_playing = true
	_stopping = false
	_set_fade(1.0)
	visible = true
	for e in _emitters:
		e[2] = false
		if e[0].one_shot:
			e[0].emitting = false
	_tick(0.0)


## Stop emitting. Particles already alive finish their life; shader parts fade out.
## One-shot effects still emit [signal finished] (and free themselves) when everything is gone.
func stop() -> void:
	if not _playing:
		return
	_stopping = true
	for e in _emitters:
		e[0].emitting = false
		e[2] = true
	_length = _t + _tail_time()


func is_playing() -> bool:
	return _playing


## Seconds a one-shot effect takes from play() until it is completely finished (at speed 1).
func get_duration() -> float:
	_collect()
	return _length


## Instance [param scene] under [param parent], place it at [param at] (global) and return it. It plays at once.
static func spawn(scene: PackedScene, parent: Node, at := Vector3.ZERO, tint := Color.WHITE, scale_by := 1.0) -> CrispFx3D:
	var fx := scene.instantiate() as CrispFx3D
	if tint != Color.WHITE:
		fx.color = tint
	if scale_by != 1.0:
		fx.fx_scale = scale_by
	parent.add_child(fx)
	fx.global_position = at
	fx.play()
	return fx


func _collect() -> void:
	if _collected:
		return
	_collected = true
	_emitters.clear()
	_animated.clear()
	_lights.clear()
	_looping = false
	var length := 0.0
	for n in _walk(self):
		if n is GPUParticles3D:
			var p: GPUParticles3D = n
			var delay: float = p.get_meta("fx_delay", 0.0)
			_emitters.append([p, delay, false])
			if p.one_shot:
				length = maxf(length, delay + p.lifetime * (2.0 - p.explosiveness) + 0.05)
			else:
				_looping = true
		elif n.has_meta("fx_duration") and _material_of(n) is ShaderMaterial:
			var loop: bool = n.get_meta("fx_loop", false)
			var hold: bool = n.get_meta("fx_hold", false)
			var delay2: float = n.get_meta("fx_delay", 0.0)
			var dur: float = n.get_meta("fx_duration", 0.5)
			_animated.append([n, delay2, dur, loop, hold, _material_of(n)])
			if loop or hold:
				_looping = true
			else:
				length = maxf(length, delay2 + dur)
		elif n is OmniLight3D and n.has_meta("fx_light"):
			_lights.append([n, n.get_meta("fx_light"), n.light_energy, n.get_meta("fx_delay", 0.0), n.get_meta("fx_duration", 0.3), n.light_color])
			if n.get_meta("fx_light") == "flicker":
				_looping = true
	_length = length + 0.05


func _walk(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is CrispFx2D or c is CrispFx3D:
			continue
		out.append(c)
		out.append_array(_walk(c))
	return out


func _material_of(n: Node) -> Material:
	return (n as GeometryInstance3D).material_override if n is GeometryInstance3D else null


func _tail_time() -> float:
	var t := 0.0
	for e in _emitters:
		t = maxf(t, e[0].lifetime)
	return t + 0.4


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if get_tree() == null or get_tree().edited_scene_root == self:
			return
		if not _playing and editor_preview and not _looping:
			_idle += delta
			if _idle > 0.7:
				play()
	if _playing:
		_tick(delta * speed)


func _tick(dt: float) -> void:
	_t += dt
	for e in _emitters:
		if not e[2] and _t >= e[1]:
			e[2] = true
			if e[0].one_shot:
				e[0].restart()
			else:
				e[0].emitting = true
	for a in _animated:
		var n = a[0]
		var p: float = (_t - a[1]) / maxf(a[2], 0.001)
		var on: bool = _t >= a[1]
		if a[3]:
			p = fposmod(p, 1.0)
		elif a[4]:
			p = clampf(p, 0.0, 1.0)
		else:
			on = on and p < 1.0
			p = clampf(p, 0.0, 1.0)
		n.visible = on
		if on:
			a[5].set_shader_parameter("progress", p)
	for l in _lights:
		var light: OmniLight3D = l[0]
		var lt: float = _t - l[3]
		if l[1] == "flash":
			var k := clampf(1.0 - lt / maxf(l[4], 0.001), 0.0, 1.0)
			light.visible = lt >= 0.0 and k > 0.0
			light.light_energy = l[2] * k * k
		else:
			var flick := 0.82 + 0.12 * sin(_t * 23.0) + 0.08 * sin(_t * 37.0 + 1.3) + 0.06 * sin(_t * 9.0)
			light.light_energy = l[2] * flick * _fade
			light.visible = lt >= 0.0
	if _stopping:
		_set_fade(clampf(_fade - dt * 3.0, 0.0, 1.0))
	if (not _looping or _stopping) and _t >= _length:
		_playing = false
		_hide_all()
		finished.emit()
		if free_on_finish and not Engine.is_editor_hint() and not _looping:
			queue_free()
		elif _stopping and free_on_finish and not Engine.is_editor_hint():
			queue_free()


func _hide_all() -> void:
	for a in _animated:
		a[0].visible = false
	for l in _lights:
		l[0].visible = false


func _apply_color() -> void:
	for n in _walk(self):
		var m := _material_of(n)
		if m is ShaderMaterial:
			m.set_shader_parameter("tint", color)
			m.set_shader_parameter("fx_fade", _fade)
		elif m is StandardMaterial3D:
			m.albedo_color = Color(color.r, color.g, color.b, color.a * _fade)
	for l in _lights:
		l[0].light_color = l[5] * color


var _orig := {}  # resource -> original colours, for recolor
var _owned := {}  # resources this instance duplicated for itself


func _apply_recolor() -> void:
	if not _collected:
		return
	var key: Color = get_meta("fx_key_color", Color(1.0, 0.8, 0.3))
	var on := recolor.a > 0.0 and recolor.s > 0.02
	var dh := recolor.h - key.h if on else 0.0
	var ds := clampf(recolor.s / maxf(key.s, 0.05), 0.0, 1.5) if on else 1.0
	if not on and _orig.is_empty():
		return
	for e in _emitters:
		var pm = e[0].process_material
		if not (pm is ParticleProcessMaterial):
			continue
		if not _owned.has(pm):
			pm = pm.duplicate(true)
			_owned[pm] = true
			e[0].process_material = pm
		if not _orig.has(pm):
			_orig[pm] = pm.color
		pm.color = _shift(_orig[pm], dh, ds)
		for tex in [pm.color_ramp, pm.color_initial_ramp]:
			if tex is GradientTexture1D and tex.gradient != null:
				var g: Gradient = tex.gradient
				if not _orig.has(g):
					_orig[g] = g.colors.duplicate()
				var cs: PackedColorArray = _orig[g].duplicate()
				for i in cs.size():
					cs[i] = _shift(cs[i], dh, ds)
				g.colors = cs
	for n in _walk(self):
		var m := _material_of(n)
		if m is ShaderMaterial and m.shader != null:
			if not _orig.has(m):
				var d := {}
				for u in m.shader.get_shader_uniform_list():
					if u["type"] == TYPE_COLOR and u["name"] != "tint":
						var v = m.get_shader_parameter(u["name"])
						if v == null:
							v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), u["name"])
						if v is Color:
							d[u["name"]] = v
				_orig[m] = d
			for k in _orig[m]:
				m.set_shader_parameter(k, _shift(_orig[m][k], dh, ds))
		elif n is Line2D and n.gradient != null:
			if not _owned.has(n.gradient):
				n.gradient = n.gradient.duplicate()
				_owned[n.gradient] = true
			var g2: Gradient = n.gradient
			if not _orig.has(g2):
				_orig[g2] = g2.colors.duplicate()
			var cs2: PackedColorArray = _orig[g2].duplicate()
			for i in cs2.size():
				cs2[i] = _shift(cs2[i], dh, ds)
			g2.colors = cs2


static func _shift(c: Color, dh: float, ds: float) -> Color:
	if dh == 0.0 and ds == 1.0:
		return c
	if c.s < 0.04:
		return c
	return Color.from_hsv(fposmod(c.h + dh, 1.0), clampf(c.s * ds, 0.0, 1.0), c.v, c.a)


func _apply_amount() -> void:
	for e in _emitters:
		e[0].amount_ratio = amount


func _apply_speed() -> void:
	for e in _emitters:
		e[0].speed_scale = speed


func _set_fade(f: float) -> void:
	_fade = f
	_apply_color()
