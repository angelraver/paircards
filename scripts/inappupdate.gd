extends Node

@onready var updater := InappUpdate.new()

func _ready() -> void:
	add_child(updater)
	updater.update_available.connect(_on_available)
	updater.update_downloaded.connect(_on_downloaded)
	updater.update_flow_failed.connect(func(r): push_warning("update fail: %s" % r))
	updater.check_for_update()

func _on_available(_version_code: int, _priority: int) -> void:
	if updater.is_flexible_allowed():
		updater.start_flexible_update()
	elif updater.is_immediate_allowed():
		updater.start_immediate_update()
		
func _on_downloaded() -> void:
	# show "Update ready, restart?" and on confirmation:
	updater.complete_flexible_update()
