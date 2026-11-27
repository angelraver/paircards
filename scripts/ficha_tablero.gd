class_name FichaTablero
extends Node3D

var tipo: int = 0
var capa: int = 0
var celda: Vector2i = Vector2i.ZERO
var textura: Texture2D = null
var material: ShaderMaterial = null
var cuerpo: StaticBody3D = null
var libre: bool = false

func construir(
	p_tipo: int,
	p_capa: int,
	p_celda: Vector2i,
	p_textura: Texture2D,
	p_ficha: Node3D,
	p_material_cara: ShaderMaterial,
	p_diametro: float,
	p_grosor: float,
	p_capa_colision: int
) -> void:
	tipo = p_tipo
	capa = p_capa
	celda = p_celda
	textura = p_textura
	material = p_material_cara

	add_child(p_ficha)

	cuerpo = StaticBody3D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.collision_layer = p_capa_colision
	cuerpo.collision_mask = 0

	var forma := CollisionShape3D.new()
	forma.name = "Forma"
	var cilindro := CylinderShape3D.new()
	cilindro.radius = p_diametro * 0.5
	cilindro.height = p_grosor
	forma.shape = cilindro
	forma.position = Vector3(0.0, -p_grosor * 0.5, 0.0)
	cuerpo.add_child(forma)

	cuerpo.set_meta("ficha", self)
	add_child(cuerpo)
