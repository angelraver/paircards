extends Node3D

# API genérica unificada - usada por main.gd
func set_element_color(color_hex: String) -> void:
	ColorUtils.apply_color(self, color_hex)

# Compatibilidad: wrapper legacy
func set_peg_color(color_hex: String) -> void:
	set_element_color(color_hex)
