extends WeavlyVariableService

const TYPE = "Variable"
const EXTERN_TYPE_MISMATCH = "Variable '%s' is a %s, but it's declared extern as a %s."

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
		var created: WeavlyModel.Variable = WeavlyDeserializer.compile_variable_from_value(
			id, value
		)
		if created == null:
			return
		_variables[id] = created

	var variable: WeavlyModel.Variable = _variables.get(id)
	if typeof(value) != typeof(variable.value):
		push_error(WRONG_TYPE % [id, type_string(typeof(value)), variable.get_type_name()])
		return

	if is_instance_of(variable, WeavlyModel.NumberVariable):
		var number_variable: WeavlyModel.NumberVariable = variable
		if number_variable.min != null:
			value = max(number_variable.min, value)
		if number_variable.max != null:
			value = min(number_variable.max, value)

	_variable_states[id] = value
	variable_changed.emit(id, value)


func get_all_ids() -> Array:
	return _variable_states.keys()
