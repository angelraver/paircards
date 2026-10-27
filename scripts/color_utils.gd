class_name ColorUtils
extends RefCounted

# Utilidad genérica para aplicar un color hex a cualquier nodo 3D
# que contenga una o varias MeshInstance3D en su jerarquía.
# Centraliza la lógica duplicada de board_frame.gd y peg.gd y
# permite reutilizarla en ramps y cualquier otro elemento.

static func apply_color(root: Node, color_hex: String) -> void:
	if color_hex.is_empty():
		return
	if not color_hex.begins_with("#"):
		color_hex = "#" + color_hex

	var new_color := Color(color_hex)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = new_color

	_apply_to_meshes_recursive(root, mat)

# Aplica el material a todas las MeshInstance3D encontradas recursivamente.
# Es más genérico que el antiguo _find_mesh_instance que solo pintaba la primera.
static func _apply_to_meshes_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.set_surface_override_material(0, mat)
	for child in node.get_children():
		_apply_to_meshes_recursive(child, mat)

# Compatibilidad: mantiene el helper original que busca la primera MeshInstance3D
static func find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := find_first_mesh_instance(child)
		if found:
			return found
	return null
