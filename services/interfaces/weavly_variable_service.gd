extends WeavlyService
class_name WeavlyVariableService

signal variable_changed(id: String, value: Variant)


func has(id: String) -> bool:
	return false


func add_variable(variable: WeavlyModel.Variable) -> void:
	pass


func get_variable(id: String, default: Variant = null) -> Variant:
	return default


func set_variable(id: String, value: Variant) -> void:
	pass


func get_all_ids() -> Array:
	return []
