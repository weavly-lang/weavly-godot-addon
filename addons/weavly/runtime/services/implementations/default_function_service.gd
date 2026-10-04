class_name WeavlyDefaultFunctionService
extends WeavlyFunctionService

const KIND = "function"
const MISSING_CALLABLE = "Can't call function '%s' because no callable is registered for it."
const WRONG_RESULT_TYPE = "Function '%s' returned a value of type '%s' instead of a %s."
const UNKNOWN_RESULT_NAME = "Function '%s' returned '%s', but no %s has that name."

var _declarations: Dictionary[String, WeavlyModel.Signature] = {}
var _callables: Dictionary[String, Callable] = {}


func add_declaration(signature: WeavlyModel.Signature) -> void:
	_declarations[signature.name] = signature


func register_function(name: String, callable: Callable) -> void:
	if WeavlyModel.Signature.can_register(KIND, name, callable, _declarations):
		_callables[name] = callable


func call_function(name: String, args: Array) -> Variant:
	if not _declarations.has(name):
		engine.report_error(WeavlyExpressionEvaluator.UNKNOWN_FUNCTION % name)
		return WeavlyExpressionEvaluator.ERROR
	var callable: Callable = _callables.get(name, Callable())
	if not callable.is_valid():
		engine.report_error(MISSING_CALLABLE % name)
		return WeavlyExpressionEvaluator.ERROR
	return _check_result(_declarations[name], callable.callv(args))


func get_unregistered() -> Array[String]:
	var names: Array[String] = []
	for name: String in _declarations:
		if not _callables.has(name):
			names.append(name)
	return names


func _check_result(signature: WeavlyModel.Signature, value: Variant) -> Variant:
	var type: String = signature.return_type
	if value is int and type == WeavlyDeserializer.TYPE_NUMBER:
		value = float(value)
	var expected: Variant = WeavlyDeserializer.VARIABLE_DEFAULTS[type]
	if typeof(value) != typeof(expected):
		engine.report_error(WRONG_RESULT_TYPE % [signature.name, type_string(typeof(value)), type])
		return WeavlyExpressionEvaluator.ERROR
	if (
		value is String
		and type != WeavlyDeserializer.TYPE_STRING
		and not engine.node_service.has_name(type, value)
	):
		engine.report_error(UNKNOWN_RESULT_NAME % [signature.name, value, type])
		return WeavlyExpressionEvaluator.ERROR
	return value
