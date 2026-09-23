@abstract class_name WeavlyVariableService
extends WeavlyService

signal variable_changed(id: String, value: Variant)

const WRONG_TYPE = "Can't set variable '%s' to a value of type '%s' because it's a %s."

@abstract func has(id: String) -> bool

@abstract func add_variable(variable: WeavlyModel.Variable) -> void

# Null when the name isn't declared; an extern declaration has no value until defined.
@abstract func get_declaration(id: String) -> WeavlyModel.Variable

@abstract func get_variable(id: String, default: Variant = null) -> Variant

@abstract func set_variable(id: String, value: Variant) -> void

@abstract func get_all_ids() -> Array
