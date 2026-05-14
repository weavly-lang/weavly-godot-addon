class_name WeavlyNumberVariable
extends Resource

@export var id: StringName
@export var value: float = 0.0
@export var has_min: bool = false
@export var min: float = 0.0
@export var has_max: bool = false
@export var max: float = 0.0


func instantiate() -> WeavlyModel.NumberVariable:
	var p_min = null
	var p_max = null
	if has_min:
		p_min = min
	if has_max:
		p_max = max
	return WeavlyModel.NumberVariable.new(id, value, p_min, p_max)
