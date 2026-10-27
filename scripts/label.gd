extends Label

@onready var mat = material as ShaderMaterial

func _process(delta: float) -> void:
	if mat:
		var current_time = mat.get_shader_parameter("u_time")
		if current_time == null:
			current_time = 0.0
		mat.set_shader_parameter("u_time", current_time + delta)
