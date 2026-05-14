extends WeavlyVariableService

const TYPE = "Variable"

var _variables: Dictionary[StringName, WeavlyModel.Variable]
var _variable_states: Dictionary[String, Variant] = {}


func has(id: String) -> bool:
	return _variable_states.has(id)


func add_variable(variable: WeavlyModel.Variable) -> void:
	if _variables.has(variable.id):
		push_warning(EXISTING_ID % [TYPE, variable.id])
		return
	_variables[variable.id] = variable
	_variable_states[variable.id] = variable.value


func get_variable(id: String, default: Variant = null) -> Variant:
	if not _variable_states.has(id):
		push_warning(MISSING_ID % [TYPE, id, default])
	return _variable_states.get(id, default)


func set_variable(id: String, value: Variant) -> void:
	if not _variables.has(id):
		_variables[id] = WeavlyDeserializer.compile_variable_from_value(id, value)

	if is_instance_of(_variables.get(id), WeavlyModel.NumberVariable):
		var number_variable: WeavlyModel.NumberVariable = _variables.get(id)
		if number_variable.min != null:
			value = max(number_variable.min, value)
		if number_variable.max != null:
			value = min(number_variable.max, value)

	_variable_states[id] = value
	variable_changed.emit(id, value)


func get_all_ids() -> Array:
	return _variable_states.keys()
