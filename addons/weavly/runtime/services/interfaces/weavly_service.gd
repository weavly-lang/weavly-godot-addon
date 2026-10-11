@abstract class_name WeavlyService
extends RefCounted

var engine: WeavlyEngine


func initialize(engine: WeavlyEngine) -> void:
	self.engine = engine


# JSON-safe values for WeavlyEngine.get_state(); empty for services without state.
func get_state() -> Dictionary:
	return {}


func set_state(_state: Dictionary) -> void:
	pass
