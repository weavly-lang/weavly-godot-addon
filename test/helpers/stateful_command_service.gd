extends "res://addons/weavly/runtime/services/implementations/default_command_service.gd"

var restored: Dictionary = {}


func get_state() -> Dictionary:
	return {"volume": 0.5}


func set_state(state: Dictionary) -> void:
	restored = state
