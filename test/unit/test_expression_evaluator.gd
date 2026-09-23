# gdlint:ignore = max-public-methods

extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

# =====================
# Helpers
# =====================


func _make_engine() -> WeavlyEngine:
	var engine: WeavlyEngine = auto_free(FakeEngine.new())
	add_child(engine)
	return engine


func _eval(expression: WeavlyModel.WeavlyExpression, engine: WeavlyEngine = null) -> Variant:
	if engine == null:
		engine = _make_engine()
	return WeavlyExpressionEvaluator.evaluate_expression(expression, engine)


func _cond(expression: WeavlyModel.WeavlyExpression) -> bool:
	return WeavlyExpressionEvaluator.evaluate_condition(expression, _make_engine())


func _num(v: float) -> WeavlyModel.Number:
	return WeavlyModel.Number.new(v)


func _slit(v: String) -> WeavlyModel.StringLiteral:
	return WeavlyModel.StringLiteral.new(v)


func _bool(v: bool) -> WeavlyModel.WeavlyExpression:
	if v:
		return WeavlyModel.TrueExpression.new()
	return WeavlyModel.FalseExpression.new()


func _id(v: StringName) -> WeavlyModel.Identifier:
	return WeavlyModel.Identifier.new(v)


func _unary(op: String, expr: WeavlyModel.WeavlyExpression) -> WeavlyModel.UnaryExpression:
	return WeavlyModel.UnaryExpression.new(op, expr)


func _bin(
	op: String,
	left: WeavlyModel.WeavlyExpression,
	right: WeavlyModel.WeavlyExpression,
) -> WeavlyModel.BinaryExpression:
	return WeavlyModel.BinaryExpression.new(op, left, right)


# =====================
# Literals
# =====================


func test_true_expression() -> void:
	assert_that(_eval(WeavlyModel.TrueExpression.new())).is_equal(true)


func test_false_expression() -> void:
	assert_that(_eval(WeavlyModel.FalseExpression.new())).is_equal(false)


func test_number() -> void:
	assert_that(_eval(_num(42.0))).is_equal(42.0)


func test_string_literal() -> void:
	assert_that(_eval(_slit("hello"))).is_equal("hello")


# =====================
# Identifier lookup
# =====================


func test_identifier_number_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("score", 10.0)
	assert_that(_eval(_id(&"score"), engine)).is_equal(10.0)


func test_identifier_string_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("name", "Alice")
	assert_that(_eval(_id(&"name"), engine)).is_equal("Alice")


func test_identifier_flag_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("active", true)
	assert_that(_eval(_id(&"active"), engine)).is_equal(true)


func test_identifier_missing_returns_error() -> void:
	assert_bool(WeavlyExpressionEvaluator.is_error(_eval(_id(&"missing")))).is_true()
	assert_logged(["Variable 'missing' isn't defined."])


# =====================
# Unary
# =====================


func test_not_true() -> void:
	assert_that(_eval(_unary("not", _bool(true)))).is_equal(false)


func test_not_false() -> void:
	assert_that(_eval(_unary("not", _bool(false)))).is_equal(true)


func test_not_type_mismatch_returns_error() -> void:
	assert_bool(WeavlyExpressionEvaluator.is_error(_eval(_unary("not", _num(1.0))))).is_true()
	assert_logged(["Can't use operator 'not' on value of type 'float'."])


func test_unknown_unary_op_returns_error() -> void:
	assert_bool(WeavlyExpressionEvaluator.is_error(_eval(_unary("~", _bool(true))))).is_true()
	assert_logged(["Unknown expression with operator '~'."])


# =====================
# Math operators
# =====================


func test_add() -> void:
	assert_that(_eval(_bin("+", _num(3.0), _num(4.0)))).is_equal(7.0)


func test_sub() -> void:
	assert_that(_eval(_bin("-", _num(10.0), _num(3.0)))).is_equal(7.0)


func test_mul() -> void:
	assert_that(_eval(_bin("*", _num(3.0), _num(4.0)))).is_equal(12.0)


func test_div() -> void:
	assert_that(_eval(_bin("/", _num(10.0), _num(4.0)))).is_equal(2.5)


func test_math_type_mismatch_returns_error() -> void:
	(
		assert_bool(WeavlyExpressionEvaluator.is_error(_eval(_bin("+", _num(1.0), _slit("x")))))
		. is_true()
	)
	assert_logged(["Can't use operator '+' on values of types 'float' and 'String'."])


func test_division_by_zero_returns_default() -> void:
	assert_that(_eval(_bin("/", _num(5.0), _num(0.0)))).is_equal(
		WeavlyExpressionEvaluator.DEFAULT_DIVISION_BY_ZERO_RETURN
	)
	assert_logged(["Division by zero detected, returning '0.0'"])


# =====================
# Comparison operators
# =====================


func test_eq_true() -> void:
	assert_that(_eval(_bin("==", _num(5.0), _num(5.0)))).is_equal(true)


func test_eq_false() -> void:
	assert_that(_eval(_bin("==", _num(5.0), _num(6.0)))).is_equal(false)


func test_neq() -> void:
	assert_that(_eval(_bin("!=", _num(5.0), _num(6.0)))).is_equal(true)


func test_less() -> void:
	assert_that(_eval(_bin("<", _num(3.0), _num(5.0)))).is_equal(true)


func test_less_eq() -> void:
	assert_that(_eval(_bin("<=", _num(5.0), _num(5.0)))).is_equal(true)


func test_greater() -> void:
	assert_that(_eval(_bin(">", _num(6.0), _num(5.0)))).is_equal(true)


func test_greater_eq() -> void:
	assert_that(_eval(_bin(">=", _num(5.0), _num(5.0)))).is_equal(true)


func test_eq_strings() -> void:
	assert_that(_eval(_bin("==", _slit("hi"), _slit("hi")))).is_equal(true)


func test_compare_type_mismatch_returns_error() -> void:
	(
		assert_bool(WeavlyExpressionEvaluator.is_error(_eval(_bin("==", _num(1.0), _slit("1")))))
		. is_true()
	)
	assert_logged(["Can't use operator '==' on values of types 'float' and 'String'."])


# =====================
# Logic operators
# =====================


func test_and_true_true() -> void:
	assert_that(_eval(_bin("and", _bool(true), _bool(true)))).is_equal(true)


func test_and_true_false() -> void:
	assert_that(_eval(_bin("and", _bool(true), _bool(false)))).is_equal(false)


func test_or_false_true() -> void:
	assert_that(_eval(_bin("or", _bool(false), _bool(true)))).is_equal(true)


func test_or_false_false() -> void:
	assert_that(_eval(_bin("or", _bool(false), _bool(false)))).is_equal(false)


func test_logic_type_mismatch_returns_error() -> void:
	(
		assert_bool(WeavlyExpressionEvaluator.is_error(_eval(_bin("and", _bool(true), _num(1.0)))))
		. is_true()
	)
	assert_logged(["Can't use operator 'and' on values of types 'bool' and 'float'."])


# =====================
# evaluate_condition
# =====================


func test_condition_bool_passthrough() -> void:
	assert_that(_cond(WeavlyModel.TrueExpression.new())).is_equal(true)


func test_condition_non_bool_returns_default() -> void:
	assert_that(_cond(_num(1.0))).is_equal(WeavlyExpressionEvaluator.DEFAULT_CONDITION_RETURN)
	assert_logged(["Condition can't be of type 'float', returning 'false' instead."])


# =====================
# Nested expressions
# =====================


func test_nested_expression() -> void:
	# (1 + 2) * 3 == 9
	var expr = _bin("==", _bin("*", _bin("+", _num(1.0), _num(2.0)), _num(3.0)), _num(9.0))
	assert_that(_eval(expr)).is_equal(true)


# =====================
# Errors
# =====================


func test_error_passes_through_operators_without_further_reports() -> void:
	var expr = _unary("not", _bin("==", _bin("+", _id(&"missing"), _num(1.0)), _num(2.0)))
	assert_bool(WeavlyExpressionEvaluator.is_error(_eval(expr))).is_true()
	assert_logged(["Variable 'missing' isn't defined."])


func test_condition_on_an_error_is_false_without_a_type_report() -> void:
	assert_bool(_cond(_id(&"missing"))).is_false()
	assert_logged(["Variable 'missing' isn't defined."])


func test_null_expression_returns_error() -> void:
	assert_bool(WeavlyExpressionEvaluator.is_error(_eval(null))).is_true()
	assert_logged(["Unknown expression of type 'Nil'."])


# =====================
# Calls
# =====================


func _engine_with_node(id: String) -> WeavlyEngine:
	var engine: WeavlyEngine = _make_engine()
	engine.node_service.add_node(WeavlyModel.WeavlyNode.new(id, []))
	return engine


func test_visited_is_false_before_a_visit() -> void:
	var engine: WeavlyEngine = _engine_with_node("shop")
	assert_that(_eval(WeavlyModel.Call.new("visited", "shop"), engine)).is_equal(false)


func test_visited_is_true_after_a_visit() -> void:
	var engine: WeavlyEngine = _engine_with_node("shop")
	engine.node_service.record_visit("shop")
	assert_that(_eval(WeavlyModel.Call.new("visited", "shop"), engine)).is_equal(true)


func test_visit_count_is_a_number() -> void:
	var engine: WeavlyEngine = _engine_with_node("shop")
	engine.node_service.record_visit("shop")
	engine.node_service.record_visit("shop")
	assert_that(_eval(WeavlyModel.Call.new("visit_count", "shop"), engine)).is_equal(2.0)


func test_call_on_an_unknown_node_returns_error() -> void:
	var result: Variant = _eval(WeavlyModel.Call.new("visited", "shpo"))
	assert_bool(WeavlyExpressionEvaluator.is_error(result)).is_true()
	assert_logged(["Node 'shpo' in visited() doesn't exist."])


func test_call_of_an_unknown_function_returns_error() -> void:
	var engine: WeavlyEngine = _engine_with_node("shop")
	var result: Variant = _eval(WeavlyModel.Call.new("bogus", "shop"), engine)
	assert_bool(WeavlyExpressionEvaluator.is_error(result)).is_true()
	assert_logged(["Unknown function 'bogus'."])
