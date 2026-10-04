@abstract class_name WeavlyVariableService
extends WeavlyService

# Whether a value is kept for the variable; an extern has none until the game sets it.
@abstract func has(id: String) -> bool

@abstract func get_value(id: String) -> Variant

# The engine has checked the value against the declaration.
@abstract func set_value(id: String, value: Variant) -> void
