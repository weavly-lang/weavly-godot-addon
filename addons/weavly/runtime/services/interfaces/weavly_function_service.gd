@abstract class_name WeavlyFunctionService
extends WeavlyService

# The engine has checked the callable against the declaration.
@abstract func register_function(name: String, callable: Callable) -> void

# The result, which the engine checks against the declaration, or WeavlyExpressionEvaluator.ERROR
# once a failure is reported. A function without a return type may await, so leave its result.
@abstract func call_function(name: String, args: Array) -> Variant

# The declared functions this service can't call; the engine reports them on first use.
@abstract func get_unregistered() -> Array[String]
