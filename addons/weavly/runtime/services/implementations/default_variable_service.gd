class_name WeavlyDefaultVariableService
extends WeavlyVariableService

const UNKNOWN_SAVED_VARIABLE = "Saved variable '%s' no longer exists, skipping it."

var _values: Dictionary[String, Variant] = {}


func has(id: String) -> bool:
	return _values.has(id)


func get_value(id: String) -> Variant:
	return _values.get(id)


func set_value(id: String, value: Variant) -> void:
	_values[id] = value


# Externs belong to the game, which saves them with its own data.
func get_state() -> Dictionary:
	var state: Dictionary = {}
	for id: String in _values:
		if not engine.story.get_variable(id).extern:
			state[id] = _values[id]
	return state


# Replaces every saved value and keeps the externs; the engine checks what's loaded.
func set_state(state: Dictionary) -> void:
	for id: String in _values.keys():
		if not engine.story.get_variable(id).extern:
			_values.erase(id)
	for id: String in state:
		var variable: WeavlyModel.Variable = engine.story.get_variable(id)
		if variable == null:
			push_warning(UNKNOWN_SAVED_VARIABLE % id)
		elif not variable.extern:
			_values[id] = state[id]
