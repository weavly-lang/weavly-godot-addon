# gdlint:ignore = max-public-methods

extends GutTest

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

# =====================
# Helpers
# =====================


func _make_engine() -> WeavlyEngine:
	return add_child_autofree(FakeEngine.new())


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
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			WeavlyModel.TrueExpression.new(), _make_engine()
		),
		true
	)


func test_false_expression() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			WeavlyModel.FalseExpression.new(), _make_engine()
		),
		false
	)


func test_number() -> void:
	assert_eq(WeavlyExpressionEvaluator.evaluate_expression(_num(42.0), _make_engine()), 42.0)


func test_string_literal() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(_slit("hello"), _make_engine()), "hello"
	)


# =====================
# Identifier lookup
# =====================


func test_identifier_number_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("score", 10.0)
	assert_eq(WeavlyExpressionEvaluator.evaluate_expression(_id(&"score"), engine), 10.0)


func test_identifier_string_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("name", "Alice")
	assert_eq(WeavlyExpressionEvaluator.evaluate_expression(_id(&"name"), engine), "Alice")


func test_identifier_flag_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("active", true)
	assert_eq(WeavlyExpressionEvaluator.evaluate_expression(_id(&"active"), engine), true)


func test_identifier_missing_returns_null() -> void:
	assert_null(WeavlyExpressionEvaluator.evaluate_expression(_id(&"missing"), _make_engine()))
	assert_engine_error(1)
	assert_push_error(1)


# =====================
# Unary
# =====================


func test_not_true() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(_unary("not", _bool(true)), _make_engine()),
		false
	)


func test_not_false() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(_unary("not", _bool(false)), _make_engine()),
		true
	)


func test_not_type_mismatch_returns_null() -> void:
	assert_null(
		WeavlyExpressionEvaluator.evaluate_expression(_unary("not", _num(1.0)), _make_engine())
	)
	assert_push_error(1)


func test_unknown_unary_op_returns_null() -> void:
	assert_null(
		WeavlyExpressionEvaluator.evaluate_expression(_unary("~", _bool(true)), _make_engine())
	)
	assert_push_error(1)


# =====================
# Math operators
# =====================


func test_add() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("+", _num(3.0), _num(4.0)), _make_engine()
		),
		7.0
	)


func test_sub() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("-", _num(10.0), _num(3.0)), _make_engine()
		),
		7.0
	)


func test_mul() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("*", _num(3.0), _num(4.0)), _make_engine()
		),
		12.0
	)


func test_div() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("/", _num(10.0), _num(4.0)), _make_engine()
		),
		2.5
	)


func test_math_type_mismatch_returns_null() -> void:
	assert_null(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("+", _num(1.0), _slit("x")), _make_engine()
		)
	)
	assert_push_error(1)


func test_division_by_zero_returns_default() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("/", _num(5.0), _num(0.0)), _make_engine()
		),
		WeavlyExpressionEvaluator.DEFAULT_DIVISION_BY_ZERO_RETURN
	)
	assert_push_error(1)


# =====================
# Comparison operators
# =====================


func test_eq_true() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("==", _num(5.0), _num(5.0)), _make_engine()
		),
		true
	)


func test_eq_false() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("==", _num(5.0), _num(6.0)), _make_engine()
		),
		false
	)


func test_neq() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("!=", _num(5.0), _num(6.0)), _make_engine()
		),
		true
	)


func test_less() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("<", _num(3.0), _num(5.0)), _make_engine()
		),
		true
	)


func test_less_eq() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("<=", _num(5.0), _num(5.0)), _make_engine()
		),
		true
	)


func test_greater() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin(">", _num(6.0), _num(5.0)), _make_engine()
		),
		true
	)


func test_greater_eq() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin(">=", _num(5.0), _num(5.0)), _make_engine()
		),
		true
	)


func test_eq_strings() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("==", _slit("hi"), _slit("hi")), _make_engine()
		),
		true
	)


func test_compare_type_mismatch_returns_null() -> void:
	assert_null(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("==", _num(1.0), _slit("1")), _make_engine()
		)
	)
	assert_push_error(1)


# =====================
# Logic operators
# =====================


func test_and_true_true() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("and", _bool(true), _bool(true)), _make_engine()
		),
		true
	)


func test_and_true_false() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("and", _bool(true), _bool(false)), _make_engine()
		),
		false
	)


func test_or_false_true() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("or", _bool(false), _bool(true)), _make_engine()
		),
		true
	)


func test_or_false_false() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("or", _bool(false), _bool(false)), _make_engine()
		),
		false
	)


func test_logic_type_mismatch_returns_null() -> void:
	assert_null(
		WeavlyExpressionEvaluator.evaluate_expression(
			_bin("and", _bool(true), _num(1.0)), _make_engine()
		)
	)
	assert_push_error(1)


# =====================
# evaluate_condition
# =====================


func test_condition_bool_passthrough() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_condition(
			WeavlyModel.TrueExpression.new(), _make_engine()
		),
		true
	)


func test_condition_non_bool_returns_default() -> void:
	assert_eq(
		WeavlyExpressionEvaluator.evaluate_condition(_num(1.0), _make_engine()),
		WeavlyExpressionEvaluator.DEFAULT_CONDITION_RETURN
	)
	assert_push_error(1)


# =====================
# Nested expressions
# =====================


func test_nested_expression() -> void:
	# (1 + 2) * 3 == 9
	var expr = _bin("==", _bin("*", _bin("+", _num(1.0), _num(2.0)), _num(3.0)), _num(9.0))
	assert_eq(WeavlyExpressionEvaluator.evaluate_expression(expr, _make_engine()), true)
