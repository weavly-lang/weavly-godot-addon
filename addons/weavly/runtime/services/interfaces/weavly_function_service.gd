@abstract class_name WeavlyFunctionService
extends WeavlyService

@abstract func add_declaration(signature: WeavlyModel.Signature) -> void

# Functions must not change state: conditions are evaluated often and in no fixed order.
@abstract func register_function(name: String, callable: Callable) -> void

# The result checked against the declaration, or WeavlyExpressionEvaluator.ERROR once a
# failure is reported.
@abstract func call_function(name: String, args: Array) -> Variant

# The declared functions without a registered callable.
@abstract func get_unregistered() -> Array[String]
