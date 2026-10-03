extends WeavlyVariableService

const TYPE = "Variable"
const UNKNOWN_SAVED_VARIABLE = "Saved variable '%s' no longer exists, skipping it."
const UNKNOWN_SAVED_NAME = "Saved variable '%s' is skipped because %s '%s' no longer exists."

var _variables: Dictionary[String, WeavlyModel.Variable]
var _variable_states: Dictionary[String, Variant] = {}


func has(id: String) -> bool:
	return _variable_states.has(id)


func add_variable(variable: WeavlyModel.Variable) -> void:
	_variables[variable.id] = variable
	if not variable.extern:
		_variable_states[variable.id] = variable.value


func get_declaration(id: String) -> WeavlyModel.Variable:
	return _variables.get(id)


func get_variable(id: String) -> Variant:
	if not _variable_states.has(id):
		push_warning(MISSING_ID % [TYPE, id])
	return _variable_states.get(id)


func set_variable(id: String, value: Variant) -> void:
	if not _variables.has(id):
		push_error(UNDECLARED % id)
		return

	var old_value: Variant = _variable_states.get(id)
	if _store(id, value) and _variable_states[id] != old_value:
		variable_changed.emit(id, _variable_states[id], old_value)


func get_all_ids() -> Array:
	return _variable_states.keys()


# Externs belong to the game, which saves them with its own data.
func get_state() -> Dictionary:
	var state: Dictionary = {}
	for id: String in _variable_states:
		if not _variables[id].extern:
			state[id] = _variable_states[id]
	return state


# Values only; every variable missing from the state keeps its default, and externs keep theirs.
func set_state(state: Dictionary) -> void:
	for variable: WeavlyModel.Variable in _variables.values():
		if not variable.extern:
			_variable_states[variable.id] = variable.value
	for id: String in state:
		if not _variables.has(id):
			push_warning(UNKNOWN_SAVED_VARIABLE % id)
			continue
		var variable: WeavlyModel.Variable = _variables[id]
		if variable.extern:
			continue
		if state[id] is String and not _names_a_declared_one(variable, state[id]):
			push_warning(UNKNOWN_SAVED_NAME % [id, variable.get_type_name(), state[id]])
			continue
		_store(id, state[id])


# Type-checks and clamps against the declaration; false when the value was rejected.
func _store(id: String, value: Variant) -> bool:
	if value is int:
		value = float(value)
	var variable: WeavlyModel.Variable = _variables.get(id)
	if typeof(value) != typeof(variable.value):
		push_error(WRONG_TYPE % [id, type_string(typeof(value)), variable.get_type_name()])
		return false
	if not _names_a_declared_one(variable, value):
		push_error(UNKNOWN_NAME % [id, value, variable.get_type_name()])
		return false

	if variable is WeavlyModel.NumberVariable:
		value = variable.clamp_value(value)

	_variable_states[id] = value
	return true


# True for every variable that doesn't hold a name.
func _names_a_declared_one(variable: WeavlyModel.Variable, value: Variant) -> bool:
	return (
		variable is not WeavlyModel.NameVariable
		or engine.node_service.has_name(variable.type, value)
	)
