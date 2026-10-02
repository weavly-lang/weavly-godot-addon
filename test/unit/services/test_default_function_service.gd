extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/runtime/services/implementations/default_function_service.gd"
)
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: FakeEngine
var _service: Service


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	_service = Service.new()
	_service.initialize(_engine)
	_service.add_declaration(
		WeavlyModel.Signature.new("double", ["number"] as Array[String], "number")
	)


func test_a_call_returns_the_result() -> void:
	_service.register_function("double", func(value: float) -> float: return value * 2.0)
	assert_that(_service.call_function("double", [2.0])).is_equal(4.0)


func test_an_int_result_for_a_number_becomes_a_float() -> void:
	_service.register_function("double", func(value: float) -> int: return int(value) * 2)
	var result: Variant = _service.call_function("double", [2.0])
	assert_int(typeof(result)).is_equal(TYPE_FLOAT)
	assert_that(result).is_equal(4.0)


func test_calling_an_undeclared_function_fails() -> void:
	var result: Variant = _service.call_function("halve", [2.0])
	assert_bool(WeavlyExpressionEvaluator.is_error(result)).is_true()
	assert_logged(["Unknown function 'halve'."])


func test_unregistered_lists_declared_functions_without_a_callable() -> void:
	assert_array(_service.get_unregistered()).is_equal(["double"])
	_service.register_function("double", func(value: float) -> float: return value)
	assert_array(_service.get_unregistered()).is_empty()
