class_name WeavlyVariableService
extends WeavlyService

signal variable_changed(id: String, value: Variant)


func has(_id: String) -> bool:
	return false


func add_variable(_variable: WeavlyModel.Variable) -> void:
	pass


func get_variable(_id: String, default: Variant = null) -> Variant:
	return default


func set_variable(_id: String, _value: Variant) -> void:
	pass


func get_all_ids() -> Array:
	return []
