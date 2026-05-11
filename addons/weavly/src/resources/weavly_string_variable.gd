extends Resource
class_name WeavlyStringVariable

@export var id: StringName
@export var value: String = ""


func instantiate() -> WeavlyModel.StringVariable:
	return WeavlyModel.StringVariable.new(id, value)
