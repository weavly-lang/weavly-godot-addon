class_name WeavlyStringVariable
extends WeavlyVariable

@export var value: String = ""


func instantiate() -> WeavlyModel.StringVariable:
	return WeavlyModel.StringVariable.new(id, value)
