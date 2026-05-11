extends Resource
class_name WeavlyFlagVariable

@export var id: StringName
@export var value: bool = false


func instantiate() -> WeavlyModel.FlagVariable:
	return WeavlyModel.FlagVariable.new(id, value)
