extends Area3D

var points: int = 0
var balls_in_slot: Dictionary = {}

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

signal ball_scored(points_awarded, ball_node)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup_slot(slot_width: float, pts: int, color_hex: String) -> void:
	points = pts
	
	# Referencias directas
	var col = $CollisionShape3D
	var bg_mesh = $BackgroundMesh
	var bg_mesh_floor = $BackgroundMeshPiso
	var label = $PointsLabel

	# 1. Ajustar el tamaño del sensor de colisión (BoxShape3D)
	if col and col.shape:
		var new_box = BoxShape3D.new()
		var current_size = col.shape.size if col.shape is BoxShape3D else Vector3(1, 0.2, 0.3)
		new_box.size = Vector3(slot_width, current_size.y, current_size.z)
		col.shape = new_box

	# 2. Ajustar el tamaño del panel de fondo (QuadMesh / PlaneMesh)
	if bg_mesh and bg_mesh_floor:
		var new_quad = QuadMesh.new()
		new_quad.size = Vector2(slot_width, 0.3)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color_hex)
		new_quad.material = mat
		
		bg_mesh.mesh = new_quad
		bg_mesh_floor.mesh = new_quad

	# 3. Actualizar el texto del Label3D
	if label:
		label.text = str(pts)

func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and not body.is_queued_for_deletion():
		balls_in_slot[body] = 0.0

func _on_body_exited(body: Node3D) -> void:
	if balls_in_slot.has(body):
		balls_in_slot.erase(body)

func _physics_process(delta: float) -> void:
	for ball in balls_in_slot.keys():
		if not is_instance_valid(ball) or ball.is_queued_for_deletion():
			balls_in_slot.erase(ball)
			continue
		
		# Si la bola ya sumó puntos previamente, la ignoramos
		if ball.get("scored") == true:
			balls_in_slot.erase(ball)
			continue

		var is_settled: bool = ball.linear_velocity.length() < 0.1 and ball.angular_velocity.length() < 0.1
		
		if is_settled:
			balls_in_slot[ball] += delta
			if balls_in_slot[ball] >= 0.4:
				ball.set("scored", true) # Marcamos la bola como puntuada
				balls_in_slot.erase(ball)
				emit_signal("ball_scored", points, ball)
		else:
			balls_in_slot[ball] = 0.0
