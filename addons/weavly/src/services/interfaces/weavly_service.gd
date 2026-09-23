@abstract class_name WeavlyService
extends RefCounted

const MISSING_ID = "%s with id '%s' doesn't exist, returning default '%s'."
const EXISTING_ID = "%s with id '%s' already exists."
const FAILED_LOADING = "Failed to load %s at path '%s' for id '%s', returning default '%s'."

var engine: WeavlyEngine


func initialize(engine: WeavlyEngine) -> void:
	self.engine = engine


# JSON-safe values for WeavlyEngine.get_state(); empty for services without state.
func get_state() -> Dictionary:
	return {}


func set_state(_state: Dictionary) -> void:
	pass
