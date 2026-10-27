extends Control

@onready var label_mat = $TextureRect/Label.material as ShaderMaterial
@onready var crt_mat = $"../CRT_EFFECT".material as ShaderMaterial

func _process(_delta: float) -> void:
	var t = Time.get_ticks_msec() / 5000.0
	
	if label_mat:
		label_mat.set_shader_parameter("u_time", t)
	if crt_mat:
		crt_mat.set_shader_parameter("u_time", t)
