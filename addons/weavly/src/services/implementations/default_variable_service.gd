extends WeavlyVariableService

const TYPE = "Variable"
const EXTERN_TYPE_MISMATCH = "Variable '%s' is a %s, but it's declared extern as a %s."
const UNKNOWN_SAVED_VARIABLE = "Saved variable '%s' no longer exists, skipping it."

var _variables: Dictionary[StringName, WeavlyModel.Variable]
var _variable_states: Dictionary[String, Variant] = {}


func has(id: String) -> bool:
	return _variable_states.has(id)


func add_variable(variable: WeavlyModel.Variable) -> void:
	var declared: WeavlyModel.Variable = _variables.get(variable.id)
	if declared != null and not (declared.extern and not variable.extern):
		push_warning(EXISTING_ID % [TYPE, variable.id])
		return
	if declared != null and declared.get_type_name() != variable.get_type_name():
		push_error(
			(
				EXTERN_TYPE_MISMATCH
				% [variable.id, variable.get_type_name(), declared.get_type_name()]
			)
		)
		return
	_variables[variable.id] = variable
	if not variable.extern:
		_variable_states[variable.id] = variable.value


func get_declaration(id: String) -> WeavlyModel.Variable:
	return _variables.get(id)


func get_variable(id: String, default: Variant = null) -> Variant:
	if not _variable_states.has(id):
		push_warning(MISSING_ID % [TYPE, id, default])
	return _variable_states.get(id, default)


func set_variable(id: String, value: Variant) -> void:
	if value is int:
		value = float(value)

	if not _variables.has(id):
		push_error(UNDECLARED % id)
		return

	if _store(id, value):
		variable_changed.emit(id, _variable_states[id])


func get_all_ids() -> Array:
	return _variable_states.keys()


func get_state() -> Dictionary:
	return _variable_states.duplicate()


# Values only; every variable missing from the state keeps its default.
func set_state(state: Dictionary) -> void:
	_variable_states.clear()
	for variable: WeavlyModel.Variable in _variables.values():
		if not variable.extern:
			_variable_states[variable.id] = variable.value
	for id: String in state:
		if not _variables.has(id):
			push_warning(UNKNOWN_SAVED_VARIABLE % id)
			continue
		var value: Variant = state[id]
		_store(id, float(value) if value is int else value)


# Type-checks and clamps against the declaration; false when the value was rejected.
func _store(id: String, value: Variant) -> bool:
	var variable: WeavlyModel.Variable = _variables.get(id)
	if typeof(value) != typeof(variable.value):
		push_error(WRONG_TYPE % [id, type_string(typeof(value)), variable.get_type_name()])
		return false

	if is_instance_of(variable, WeavlyModel.NumberVariable):
		var number_variable: WeavlyModel.NumberVariable = variable
		if number_variable.min != null:
			value = max(number_variable.min, value)
		if number_variable.max != null:
			value = min(number_variable.max, value)

	_variable_states[id] = value
	return true
