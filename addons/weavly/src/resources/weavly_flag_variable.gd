class_name WeavlyFlagVariable
extends WeavlyVariable

@export var value: bool = false


func instantiate() -> WeavlyModel.FlagVariable:
	return WeavlyModel.FlagVariable.new(id, value)
