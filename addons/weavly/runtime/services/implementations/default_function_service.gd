class_name WeavlyDefaultFunctionService
extends WeavlyFunctionService

const MISSING_CALLABLE = "Can't call function '%s' because no callable is registered for it."

var _callables: Dictionary[String, Callable] = {}


func register_function(name: String, callable: Callable) -> void:
	_callables[name] = callable


func call_function(name: String, args: Array) -> Variant:
	var callable: Callable = _callables.get(name, Callable())
	if not callable.is_valid():
		engine.report_error(MISSING_CALLABLE % name)
		return WeavlyExpressionEvaluator.ERROR
	return callable.callv(args)


func get_unregistered() -> Array[String]:
	var names: Array[String] = []
	for name: String in engine.story.get_function_names():
		if not _callables.has(name):
			names.append(name)
	return names
