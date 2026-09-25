class_name WeavlyNumberVariable
extends WeavlyVariable

@export var value: float = 0.0
@export var has_min: bool = false
@export var min: float = 0.0
@export var has_max: bool = false
@export var max: float = 0.0


func instantiate() -> WeavlyModel.NumberVariable:
	var lower: Variant = min if has_min else null
	var upper: Variant = max if has_max else null
	return WeavlyModel.NumberVariable.new(id, value, lower, upper)
