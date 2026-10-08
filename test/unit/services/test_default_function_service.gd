extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _service: WeavlyDefaultFunctionService


func before_test() -> void:
	var engine: FakeEngine = auto_free(FakeEngine.new())
	engine.story.add_function(
		WeavlyModel.Signature.new("double", ["number"] as Array[String], "number")
	)
	_service = engine.function_service


func test_a_call_returns_the_result() -> void:
	_service.register_function("double", func(value: float) -> float: return value * 2.0)
	assert_that(_service.call_function("double", [2.0])).is_equal(4.0)


func test_a_function_without_a_return_type_gives_no_result() -> void:
	_service.engine.story.add_function(WeavlyModel.Signature.new("wave", []))
	var waved: Array[bool] = [false]
	_service.register_function(
		"wave",
		func() -> int:
			waved[0] = true
			return 1
	)
	assert_object(_service.call_function("wave", [])).is_null()
	assert_bool(waved[0]).is_true()


func test_calling_a_function_without_a_callable_fails() -> void:
	var result: Variant = _service.call_function("double", [2.0])
	assert_bool(WeavlyExpressionEvaluator.is_error(result)).is_true()
	assert_logged(["Can't call function 'double' because no callable is registered for it."])


func test_unregistered_lists_declared_functions_without_a_callable() -> void:
	assert_array(_service.get_unregistered()).is_equal(["double"])
	_service.register_function("double", func(value: float) -> float: return value)
	assert_array(_service.get_unregistered()).is_empty()
