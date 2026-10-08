class_name WeavlyExpressionEvaluator

const UNKNOWN_EXPRESSION_TYPE = "Unknown expression of type '%s'."
const UNKNOWN_FUNCTION = "Unknown function '%s'."
const WRONG_RESULT_TYPE = "Function '%s' returned a value of type '%s' instead of a %s."
const UNKNOWN_RESULT_NAME = "Function '%s' returned '%s', but no %s has that name."
const UNKNOWN_NODE = "Node '%s' in %s() doesn't exist."
const WRONG_ARGUMENT_TYPE = "%s() takes numbers, got a value of type '%s'."
const UNKNOWN_OPERATOR = "Unknown expression with operator '%s'."
const WRONG_CONDITION_TYPE = "Condition can't be of type '%s', returning '%s' instead."
const WRONG_VALUE_TYPE = "Can't use operator '%s' on value of type '%s'."
const WRONG_VALUE_TYPES = "Can't use operator '%s' on values of types '%s' and '%s'."
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

const RANDOM = "random"

const VISITED = "visited"
const VISIT_COUNT = "visit_count"
const SKIP_COUNT = "skip_count"
const NODE_FUNCTIONS = [VISITED, VISIT_COUNT, SKIP_COUNT]
const META = "meta"

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
	RANDOM: [2, 2, _random],
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
	if expression is WeavlyModel.TextExpression:
		return WeavlyTextUtils.fill_text(expression.segments, engine)
	if expression is WeavlyModel.Identifier:
		return evaluate_identifier(expression, engine)
	if expression is WeavlyModel.Call:
		return evaluate_call(expression, engine)
	if expression is WeavlyModel.MetaCall:
		return WeavlyMetaReader.read(engine, expression.node_id, expression.key)
	if expression is WeavlyModel.UnaryExpression:
		return evaluate_unary_expression(expression, engine)
	if expression is WeavlyModel.BinaryExpression:
		return evaluate_binary_expression(expression, engine)

	engine.report_error(UNKNOWN_EXPRESSION_TYPE % _get_type(expression))
	return ERROR


static func evaluate_identifier(
	identifier: WeavlyModel.Identifier, engine: WeavlyEngine
) -> Variant:
	var value: Variant = engine.get_variable(identifier.value)
	return ERROR if value == null else value


# The value, an int as a number, or ERROR after reporting why it doesn't fit the type. The messages
# take the subject, then the value's type or the value, then the type.
static func fit(
	value: Variant,
	type: String,
	subject: String,
	wrong_type: String,
	unknown_name: String,
	engine: WeavlyEngine
) -> Variant:
	if value is int and type == WeavlyDeserializer.TYPE_NUMBER:
		value = float(value)
	match engine.story.fit(type, value):
		WeavlyStory.Fit.WRONG_TYPE:
			engine.report_error(wrong_type % [subject, type_string(typeof(value)), type])
			return ERROR
		WeavlyStory.Fit.UNKNOWN_NAME:
			engine.report_error(unknown_name % [subject, value, type])
			return ERROR
	return value


static func evaluate_call(call: WeavlyModel.Call, engine: WeavlyEngine) -> Variant:
	if is_number_function(call.name):
		return _evaluate_number_call(call, engine)
	if call.name not in NODE_FUNCTIONS:
		return _evaluate_declared_call(call, engine)
	if not engine.story.has_node(call.node_id):
		engine.report_error(UNKNOWN_NODE % [call.node_id, call.name])
		return ERROR
	if call.name == SKIP_COUNT:
		return float(engine.count_service.get_skip_count(call.node_id))
	var count: int = engine.count_service.get_visit_count(call.node_id)
	if call.name == VISITED:
		return count > 0
	return float(count)


static func _evaluate_declared_call(call: WeavlyModel.Call, engine: WeavlyEngine) -> Variant:
	var values: Variant = evaluate_arguments(call.args, engine)
	if is_error(values):
		return ERROR
	return call_function(call.name, values, engine)


# The values in order, or ERROR once one fails.
static func evaluate_arguments(
	args: Array[WeavlyModel.WeavlyExpression], engine: WeavlyEngine
) -> Variant:
	var values: Array = []
	for arg: WeavlyModel.WeavlyExpression in args:
		var value: Variant = evaluate_expression(arg, engine)
		if is_error(value):
			return ERROR
		values.append(value)
	return values


# The result checked against the declaration; a function without a return type gives null.
static func call_function(name: String, values: Array, engine: WeavlyEngine) -> Variant:
	var signature: WeavlyModel.Signature = engine.story.get_function(name)
	if signature == null:
		engine.report_error(UNKNOWN_FUNCTION % name)
		return ERROR
	var result: Variant = engine.function_service.call_function(name, values)
	if is_error(result):
		return ERROR
	if signature.return_type == "":
		return null
	return fit(result, signature.return_type, name, WRONG_RESULT_TYPE, UNKNOWN_RESULT_NAME, engine)


static func _evaluate_number_call(call: WeavlyModel.Call, engine: WeavlyEngine) -> Variant:
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
	if call.name == RANDOM:
		implementation = implementation.bind(engine.rng)
	return implementation.call(values)


# A whole number between the two bounds, in either order, both included.
static func _random(values: Array[float], rng: RandomNumberGenerator) -> float:
	var low: int = ceili(minf(values[0], values[1]))
	var high: int = floori(maxf(values[0], values[1]))
	if low > high:
		return float(roundi(values[0]))
	return float(rng.randi_range(low, high))


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
	if not _is_bool_operand(value, unary_expression.op, engine):
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
	if not _is_bool_operand(left, op, engine):
		return ERROR
	if (op == AND and not left) or (op == OR and left):
		return left

	var right: Variant = evaluate_expression(binary_expression.right, engine)
	if not _is_bool_operand(right, op, engine):
		return ERROR
	return right


# False for an error or a value that isn't a bool; a wrong type is reported.
static func _is_bool_operand(value: Variant, op: String, engine: WeavlyEngine) -> bool:
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
	if right == 0:
		engine.report_error(DIVISION_BY_ZERO % DEFAULT_DIVISION_BY_ZERO_RETURN)
		return DEFAULT_DIVISION_BY_ZERO_RETURN
	return left / right


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
	return left > right or equal


# Tighter than is_equal_approx, which treats 1000000 and 1000001 as equal.
static func approximately_equal(a: float, b: float) -> bool:
	return absf(a - b) <= NUMBER_TOLERANCE * maxf(1.0, maxf(absf(a), absf(b)))


static func _get_type(value: Variant) -> String:
	return type_string(typeof(value))
