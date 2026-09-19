class_name WeavlyExpressionEvaluator

const UNKNOWN_EXPRESSION_TYPE = "Unknown expression of type '%s'."
const UNKNOWN_OPERATOR = "Unknown expression with operator '%s'."
const WRONG_CONDITION_TYPE = "Condition can't be of type '%s', returning '%s' instead."
const WRONG_VALUE_TYPE = "Can't use operator '%s' on value of type '%s'."
const WRONG_VALUE_TYPES = "Can't use operator '%s' on values of types '%s' and '%s'."
const NULL_VARIABLE = "Variable with ID '%s' is null."
const DIVISION_BY_ZERO = "Division by zero detected, returning '%s'"

const NOT = "not"
const AND = "and"
const OR = "or"

const ADD = "+"
const SUB = "-"
const MUL = "*"
const DIV = "/"

const EQ = "=="
const NEQ = "!="
const LESS = "<"
const LESS_EQ = "<="
const GREATER = ">"
const GREATER_EQ = ">="

const DEFAULT_CONDITION_RETURN: bool = false
const DEFAULT_DIVISION_BY_ZERO_RETURN: float = 0.0


static func evaluate_condition(
	expression: WeavlyModel.WeavlyExpression, engine: WeavlyEngine
) -> bool:
	var value = evaluate_expression(expression, engine)
	if value is not bool:
		push_error(WRONG_CONDITION_TYPE % [_get_type(value), DEFAULT_CONDITION_RETURN])
		return DEFAULT_CONDITION_RETURN

	return value


static func evaluate_expression(
	expression: WeavlyModel.WeavlyExpression, engine: WeavlyEngine
) -> Variant:
	if is_instance_of(expression, WeavlyModel.TrueExpression):
		return true
	if is_instance_of(expression, WeavlyModel.FalseExpression):
		return false
	if is_instance_of(expression, WeavlyModel.Number):
		return expression.value
	if is_instance_of(expression, WeavlyModel.StringLiteral):
		return expression.value
	if is_instance_of(expression, WeavlyModel.Identifier):
		return evaluate_identifier(expression, engine)
	if is_instance_of(expression, WeavlyModel.UnaryExpression):
		return evaluate_unary_expression(expression, engine)
	if is_instance_of(expression, WeavlyModel.BinaryExpression):
		return evaluate_binary_expression(expression, engine)

	push_error(UNKNOWN_EXPRESSION_TYPE % expression.get_class())
	return null


static func evaluate_identifier(
	identifier: WeavlyModel.Identifier, engine: WeavlyEngine
) -> Variant:
	var value: Variant = engine.variable_service.get_variable(identifier.value)
	if value == null:
		push_error(NULL_VARIABLE % identifier.value)
	return value


static func evaluate_unary_expression(
	unary_expression: WeavlyModel.UnaryExpression, engine: WeavlyEngine
) -> Variant:
	var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(
		unary_expression.expression, engine
	)
	if unary_expression.op == NOT:
		if value is bool:
			return not value

		push_error(WRONG_VALUE_TYPE % [unary_expression.op, _get_type(value)])
		return null

	push_error(UNKNOWN_OPERATOR % [unary_expression.op])
	return null


static func evaluate_binary_expression(
	binary_expression: WeavlyModel.BinaryExpression, engine: WeavlyEngine
) -> Variant:
	var op = binary_expression.op
	var left: Variant = WeavlyExpressionEvaluator.evaluate_expression(
		binary_expression.left, engine
	)
	var right: Variant = WeavlyExpressionEvaluator.evaluate_expression(
		binary_expression.right, engine
	)

	if op in [AND, OR]:
		return evaluate_logic_expression(op, left, right)
	if op in [ADD, SUB, MUL, DIV]:
		return evaluate_math_expression(op, left, right)
	if op in [EQ, NEQ, LESS, LESS_EQ, GREATER, GREATER_EQ]:
		return evaluate_compare_expression(op, left, right)

	push_error(UNKNOWN_OPERATOR % op)
	return null


static func evaluate_logic_expression(op: String, left: Variant, right: Variant) -> Variant:
	if left is not bool or right is not bool:
		push_error(WRONG_VALUE_TYPES % [op, _get_type(left), _get_type(right)])
		return null

	if op == AND:
		return left and right
	if op == OR:
		return left or right

	push_error(UNKNOWN_OPERATOR % op)
	return null


static func evaluate_math_expression(op: String, left: Variant, right: Variant) -> Variant:
	if left is not float or right is not float:
		push_error(WRONG_VALUE_TYPES % [op, _get_type(left), _get_type(right)])
		return null

	if op == ADD:
		return left + right
	if op == SUB:
		return left - right
	if op == MUL:
		return left * right
	if op == DIV:
		if right == 0:
			push_error(DIVISION_BY_ZERO % DEFAULT_DIVISION_BY_ZERO_RETURN)
			return DEFAULT_DIVISION_BY_ZERO_RETURN

		return left / right

	push_error(UNKNOWN_OPERATOR % op)
	return null


static func evaluate_compare_expression(op: String, left: Variant, right: Variant) -> Variant:
	if typeof(left) != typeof(right):
		push_error(WRONG_VALUE_TYPES % [op, _get_type(left), _get_type(right)])
		return null

	if op == EQ:
		return left == right
	if op == NEQ:
		return left != right
	if op == LESS:
		return left < right
	if op == LESS_EQ:
		return left <= right
	if op == GREATER:
		return left > right
	if op == GREATER_EQ:
		return left >= right

	push_error(UNKNOWN_OPERATOR % op)
	return null


static func _get_type(value: Variant) -> String:
	return type_string(typeof(value))
