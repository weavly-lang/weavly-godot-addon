class_name WeavlyFlagVariable
extends Resource

@export var id: StringName
@export var value: bool = false


func instantiate() -> WeavlyModel.FlagVariable:
	return WeavlyModel.FlagVariable.new(id, value)
