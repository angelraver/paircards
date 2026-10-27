extends Node3D

# API genérica unificada - misma que board_frame.gd y peg.gd
func set_element_color(color_hex: String) -> void:
	ColorUtils.apply_color(self, color_hex)

# Alias legacy por consistencia con set_board_color / set_peg_color
func set_ramp_color(color_hex: String) -> void:
	set_element_color(color_hex)
