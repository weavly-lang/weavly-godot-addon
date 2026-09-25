class_name WeavlyExpressionEvaluator

const UNKNOWN_EXPRESSION_TYPE = "Unknown expression of type '%s'."
const UNDEFINED_VARIABLE = "Variable '%s' isn't defined."
const UNDEFINED_EXTERN = "Variable '%s' is declared extern but was never defined."
const UNKNOWN_FUNCTION = "Unknown function '%s'."
const UNKNOWN_NODE = "Node '%s' in %s() doesn't exist."
const WRONG_ARGUMENT_TYPE = "%s() takes numbers, got a value of type '%s'."
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

const VISITED = "visited"
const VISIT_COUNT = "visit_count"
const NODE_FUNCTIONS = [VISITED, VISIT_COUNT]

const DEFAULT_CONDITION_RETURN: bool = false
const DEFAULT_DIVISION_BY_ZERO_RETURN: float = 0.0
const NUMBER_TOLERANCE: float = 1e-9

# Returned when evaluation fails; the failure has already been reported.
# gdlint:ignore = class-variable-name
static var ERROR: EvaluationError = EvaluationError.new()


class EvaluationError:
	extends RefCounted


# name -> [minimum argument count, maximum or -1 for no limit, implementation]
static var _number_functions: Dictionary = {
	"random": [2, 2, _random],
	"min": [2, -1, func(values: Array[float]) -> float: return values.min()],
	"max": [2, -1, func(values: Array[float]) -> float: return values.max()],
	"clamp": [3, 3, _clamp],
	"round": [1, 1, func(values: Array[float]) -> float: return roundf(values[0])],
	"floor": [1, 1, func(values: Array[float]) -> float: return floorf(values[0])],
	"ceil": [1, 1, func(values: Array[float]) -> float: return ceilf(values[0])],
	"abs": [1, 1, func(values: Array[float]) -> float: return absf(values[0])],
}


static func is_error(value: Variant) -> bool:
	return value is EvaluationError


static func is_number_function(name: String) -> bool:
	return _number_functions.has(name)


# Empty when the count fits, worded like the compiler's error otherwise.
static func argument_count_error(name: String, count: int) -> String:
	var minimum: int = _number_functions[name][0]
	var maximum: int = _number_functions[name][1]
	if count >= minimum and (maximum == -1 or count <= maximum):
		return ""
	var expected: String = "at least %d" % minimum if maximum == -1 else str(minimum)
	var noun: String = "argument" if expected == "1" else "arguments"
	return "%s() takes %s %s, got %d" % [name, expected, noun, count]


static func evaluate_condition(
	expression: WeavlyModel.WeavlyExpression, engine: WeavlyEngine
) -> bool:
	var value: Variant = evaluate_expression(expression, engine)
	if is_error(value):
		return DEFAULT_CONDITION_RETURN
	if value is not bool:
		engine.report_error(WRONG_CONDITION_TYPE % [_get_type(value), DEFAULT_CONDITION_RETURN])
		return DEFAULT_CONDITION_RETURN

	return value


static func evaluate_expression(
	expression: WeavlyModel.WeavlyExpression, engine: WeavlyEngine
) -> Variant:
	if expression is WeavlyModel.TrueExpression:
		return true
	if expression is WeavlyModel.FalseExpression:
		return false
	if expression is WeavlyModel.Number:
		return expression.value
	if expression is WeavlyModel.StringLiteral:
		return expression.value
	if expression is WeavlyModel.Identifier:
		return evaluate_identifier(expression, engine)
	if expression is WeavlyModel.Call:
		return evaluate_call(expression, engine)
	if expression is WeavlyModel.UnaryExpression:
		return evaluate_unary_expression(expression, engine)
	if expression is WeavlyModel.BinaryExpression:
		return evaluate_binary_expression(expression, engine)

	engine.report_error(UNKNOWN_EXPRESSION_TYPE % _get_type(expression))
	return ERROR


static func evaluate_identifier(
	identifier: WeavlyModel.Identifier, engine: WeavlyEngine
) -> Variant:
	if not engine.variable_service.has(identifier.value):
		report_undefined_variable(identifier.value, engine)
		return ERROR
	var value: Variant = engine.variable_service.get_variable(identifier.value)
	if value == null:
		engine.report_error(NULL_VARIABLE % identifier.value)
		return ERROR
	return value


static func report_undefined_variable(id: String, engine: WeavlyEngine) -> void:
	var declared: WeavlyModel.Variable = engine.variable_service.get_declaration(id)
	engine.report_error((UNDEFINED_EXTERN if declared != null else UNDEFINED_VARIABLE) % id)


static func evaluate_call(call: WeavlyModel.Call, engine: WeavlyEngine) -> Variant:
	if is_number_function(call.name):
		return _evaluate_number_call(call, engine)
	if call.name not in NODE_FUNCTIONS:
		engine.report_error(UNKNOWN_FUNCTION % call.name)
		return ERROR
	if not engine.node_service.has(call.node_id):
		engine.report_error(UNKNOWN_NODE % [call.node_id, call.name])
		return ERROR
	var count: int = engine.node_service.get_visit_count(call.node_id)
	if call.name == VISITED:
		return count > 0
	return float(count)


static func _evaluate_number_call(call: WeavlyModel.Call, engine: WeavlyEngine) -> Variant:
	var count_error: String = argument_count_error(call.name, call.args.size())
	if count_error != "":
		engine.report_error(count_error + ".")
		return ERROR
	var values: Array[float] = []
	for arg: WeavlyModel.WeavlyExpression in call.args:
		var value: Variant = evaluate_expression(arg, engine)
		if is_error(value):
			return ERROR
		if value is not float:
			engine.report_error(WRONG_ARGUMENT_TYPE % [call.name, _get_type(value)])
			return ERROR
		values.append(value)
	var implementation: Callable = _number_functions[call.name][2]
	return implementation.call(values)


# A whole number between the two bounds, in either order, both included.
static func _random(values: Array[float]) -> float:
	var low: int = ceili(minf(values[0], values[1]))
	var high: int = floori(maxf(values[0], values[1]))
	if low > high:
		return float(roundi(values[0]))
	return float(randi_range(low, high))


static func _clamp(values: Array[float]) -> float:
	return clampf(values[0], minf(values[1], values[2]), maxf(values[1], values[2]))


static func evaluate_unary_expression(
	unary_expression: WeavlyModel.UnaryExpression, engine: WeavlyEngine
) -> Variant:
	var value: Variant = evaluate_expression(unary_expression.expression, engine)
	if is_error(value):
		return ERROR
	if unary_expression.op != NOT:
		engine.report_error(UNKNOWN_OPERATOR % unary_expression.op)
		return ERROR
	if not _is_flag_operand(value, unary_expression.op, engine):
		return ERROR
	return not value


static func evaluate_binary_expression(
	binary_expression: WeavlyModel.BinaryExpression, engine: WeavlyEngine
) -> Variant:
	var op: String = binary_expression.op
	if op in [AND, OR]:
		return evaluate_logic_expression(binary_expression, engine)

	var left: Variant = evaluate_expression(binary_expression.left, engine)
	var right: Variant = evaluate_expression(binary_expression.right, engine)
	if is_error(left) or is_error(right):
		return ERROR

	match op:
		ADD, SUB, MUL, DIV:
			return evaluate_math_expression(op, left, right, engine)
		EQ, NEQ, LESS, LESS_EQ, GREATER, GREATER_EQ:
			return evaluate_compare_expression(op, left, right, engine)

	engine.report_error(UNKNOWN_OPERATOR % op)
	return ERROR


# The right side is only evaluated when the left side doesn't decide the result.
static func evaluate_logic_expression(
	binary_expression: WeavlyModel.BinaryExpression, engine: WeavlyEngine
) -> Variant:
	var op: String = binary_expression.op
	var left: Variant = evaluate_expression(binary_expression.left, engine)
	if not _is_flag_operand(left, op, engine):
		return ERROR
	if (op == AND and not left) or (op == OR and left):
		return left

	var right: Variant = evaluate_expression(binary_expression.right, engine)
	if not _is_flag_operand(right, op, engine):
		return ERROR
	return right


# False for an error or a value that isn't a flag; a wrong type is reported.
static func _is_flag_operand(value: Variant, op: String, engine: WeavlyEngine) -> bool:
	if is_error(value):
		return false
	if value is not bool:
		engine.report_error(WRONG_VALUE_TYPE % [op, _get_type(value)])
		return false
	return true


static func evaluate_math_expression(
	op: String, left: Variant, right: Variant, engine: WeavlyEngine
) -> Variant:
	if left is not float or right is not float:
		engine.report_error(WRONG_VALUE_TYPES % [op, _get_type(left), _get_type(right)])
		return ERROR

	match op:
		ADD:
			return left + right
		SUB:
			return left - right
		MUL:
			return left * right
		DIV:
			if right == 0:
				engine.report_error(DIVISION_BY_ZERO % DEFAULT_DIVISION_BY_ZERO_RETURN)
				return DEFAULT_DIVISION_BY_ZERO_RETURN
			return left / right

	engine.report_error(UNKNOWN_OPERATOR % op)
	return ERROR


static func evaluate_compare_expression(
	op: String, left: Variant, right: Variant, engine: WeavlyEngine
) -> Variant:
	if typeof(left) != typeof(right):
		engine.report_error(WRONG_VALUE_TYPES % [op, _get_type(left), _get_type(right)])
		return ERROR

	# Approximately equal numbers count as equal, so 0.1 + 0.2 == 0.3.
	var equal: bool = approximately_equal(left, right) if left is float else left == right
	match op:
		EQ:
			return equal
		NEQ:
			return not equal
		LESS:
			return left < right and not equal
		LESS_EQ:
			return left < right or equal
		GREATER:
			return left > right and not equal
		GREATER_EQ:
			return left > right or equal

	engine.report_error(UNKNOWN_OPERATOR % op)
	return ERROR


# Tighter than is_equal_approx, which treats 1000000 and 1000001 as equal.
static func approximately_equal(a: float, b: float) -> bool:
	return absf(a - b) <= NUMBER_TOLERANCE * maxf(1.0, maxf(absf(a), absf(b)))


static func _get_type(value: Variant) -> String:
	return type_string(typeof(value))
