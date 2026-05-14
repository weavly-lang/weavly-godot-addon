class_name WeavlyCompiler
extends RefCounted

# =====================
# Field Keys
# =====================

# Top-level keys
const KEY_NODES = "nodes"
const KEY_DECLARATIONS = "declarations"

# Common keys
const KEY_ID = "id"
const KEY_BODY = "body"
const KEY_TYPE = "type"
const KEY_TEXT = "text"
const KEY_WEIGHT = "weight"
const KEY_MODIFIER = "modifier"

# Expression keys
const KEY_EXPRESSION = "expression"
const KEY_CONDITION = "condition"
const KEY_VARIABLE = "variable"
const KEY_OP = "op"
const KEY_LEFT = "left"
const KEY_RIGHT = "right"

# Block keys
const KEY_CASES = "cases"
const KEY_OPTIONS = "items"
const KEY_HINT = "hint"

# Variable keys
const KEY_NAME = "name"
const KEY_VALUE = "value"
const KEY_MIN = "min"
const KEY_MAX = "max"

# Type values
const TYPE_NARRATION = "narration"
const TYPE_CHARACTER = "character"
const TYPE_MATCH = "match"
const TYPE_OPTION = "option"
const TYPE_SET = "set"
const TYPE_GOTO = "goto"
const TYPE_FINISH = "finish"
const TYPE_COMMAND = "command"
const TYPE_NUMBER = "number"
const TYPE_STRING = "string"
const TYPE_FLAG = "flag"
const TYPE_RANDOM = "random"

# =====================
# Helpers
# =====================


static func _path_join(path: String, key: String) -> String:
	return "%s.%s" % [path, key] if path != "" else key


static func _path_index(path: String, idx: int) -> String:
	return "%s[%d]" % [path, idx]


static func get_required(
	data: Dictionary, key: String, expected: Variant.Type, path: String = ""
) -> Variant:
	if path == "":
		path = "<root>"

	if not data.has(key):
		push_error("Missing required field '%s' at %s" % [key, path])
		return null

	var value = data.get(key)
	if value == null:
		push_error("Required field '%s' is null at %s" % [key, path])
		return null

	if typeof(value) == expected or expected == Variant.Type.TYPE_NIL:
		return value

	push_error(
		(
			"Required field '%s' has wrong type at %s, expected '%s' got '%s'"
			% [key, path, type_string(expected), type_string(typeof(value))]
		)
	)
	return null


# =====================
# Nodes
# =====================


static func compile_nodes(data: Dictionary) -> Array[WeavlyModel.WeavlyNode]:
	var path = ""
	var nodes_arr = get_required(data, KEY_NODES, Variant.Type.TYPE_ARRAY, path)
	var nodes: Array[WeavlyModel.WeavlyNode] = []
	for i in range(nodes_arr.size()):
		var node_data = nodes_arr[i]
		if not (node_data is Dictionary):
			push_error("nodes[%d] must be a Dictionary, got %s" % [i, str(typeof(node_data))])
			continue
		nodes.append(compile_node(node_data, _path_index(KEY_NODES, i)))
	return nodes


static func compile_node(data: Dictionary, path: String) -> WeavlyModel.WeavlyNode:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var body_arr = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	var body = compile_statements(body_arr, _path_join(path, KEY_BODY))
	return WeavlyModel.WeavlyNode.new(id, body)


# =====================
# Statements
# =====================


static func compile_statements(data: Array, path: String) -> Array[WeavlyModel.Statement]:
	var statements: Array[WeavlyModel.Statement] = []
	for i in range(data.size()):
		var statement = data[i]
		if not (statement is Dictionary):
			push_error(
				(
					"%s must contain Dictionaries; got %s at %s"
					% [path, str(typeof(statement)), _path_index(path, i)]
				)
			)
			continue
		statements.append(compile_statement(statement, _path_index(path, i)))
	return statements


static func compile_statement(data: Dictionary, path: String) -> WeavlyModel.Statement:
	var type = get_required(data, KEY_TYPE, Variant.Type.TYPE_STRING, path)

	match type:
		TYPE_NARRATION:
			return compile_narration_line(data, path)
		TYPE_CHARACTER:
			return compile_character_line(data, path)
		TYPE_MATCH:
			return compile_match_block(data, path)
		TYPE_OPTION:
			return compile_option_block(data, path)
		TYPE_SET:
			return compile_set_statement(data, path)
		TYPE_GOTO:
			return compile_goto_statement(data, path)
		TYPE_FINISH:
			return compile_finish_statement(data, path)
		TYPE_COMMAND:
			return compile_command_statement(data, path)
		TYPE_RANDOM:
			return compile_random_block(data, path)
		_:
			push_error("Unknown statement type '%s' at %s" % [type, path])
			return null


static func compile_narration_line(data: Dictionary, path: String) -> WeavlyModel.NarrationLine:
	var text = get_required(data, KEY_TEXT, Variant.Type.TYPE_STRING, path)
	return WeavlyModel.NarrationLine.new(text)


static func compile_character_line(data: Dictionary, path: String) -> WeavlyModel.CharacterLine:
	var name = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING, path)
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_BOOL, path)
	var text = get_required(data, KEY_TEXT, Variant.Type.TYPE_STRING, path)
	return WeavlyModel.CharacterLine.new(name, id, text)


static func compile_set_statement(data: Dictionary, path: String) -> WeavlyModel.SetStatement:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var expr_data = get_required(data, KEY_EXPRESSION, Variant.Type.TYPE_NIL, path)
	var expr = compile_expression(expr_data, _path_join(path, KEY_EXPRESSION))
	return WeavlyModel.SetStatement.new(id, expr)


static func compile_goto_statement(data: Dictionary, path: String) -> WeavlyModel.GotoStatement:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	return WeavlyModel.GotoStatement.new(id)


static func compile_finish_statement(
	_data: Dictionary, _path: String
) -> WeavlyModel.FinishStatement:
	return WeavlyModel.FinishStatement.new()


static func compile_command_statement(
	data: Dictionary, path: String
) -> WeavlyModel.CommandStatement:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var text = get_required(data, KEY_TEXT, Variant.Type.TYPE_STRING, path)
	return WeavlyModel.CommandStatement.new(id, text)


# =====================
# Match Block
# =====================


static func compile_match_block(data: Dictionary, path: String) -> WeavlyModel.MatchBlock:
	var modifier_string = get_required(data, KEY_MODIFIER, Variant.Type.TYPE_STRING, path)
	var case_data_list = get_required(data, KEY_CASES, TYPE_ARRAY, path)

	var modifier: WeavlyModel.MatchModifier
	match modifier_string:
		"first":
			modifier = WeavlyModel.MatchModifier.FIRST
		"last":
			modifier = WeavlyModel.MatchModifier.LAST
		"all":
			modifier = WeavlyModel.MatchModifier.ALL

	var cases: Array[WeavlyModel.WhenCase] = []
	for i in range(case_data_list.size()):
		var case_data = case_data_list[i]
		var case_path = _path_index(_path_join(path, KEY_CASES), i)
		if not (case_data is Dictionary):
			push_error("%s must be a Dictionary; got %s" % [case_path, str(typeof(case_data))])
			continue
		cases.append(compile_when_case(case_data, case_path))

	return WeavlyModel.MatchBlock.new(modifier, cases)


static func compile_when_case(data: Dictionary, path: String) -> WeavlyModel.WhenCase:
	var condition_data = get_required(data, KEY_CONDITION, Variant.Type.TYPE_NIL, path)
	var condition = compile_expression(condition_data, _path_join(path, KEY_CONDITION))
	var body_data_list = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	var body = compile_statements(body_data_list, _path_join(path, KEY_BODY))
	return WeavlyModel.WhenCase.new(condition, body)


# =====================
# Option Block
# =====================


static func compile_option_block(data: Dictionary, path: String) -> WeavlyModel.OptionBlock:
	var option_data_list = get_required(data, KEY_OPTIONS, Variant.Type.TYPE_ARRAY, path)
	var options: Array[WeavlyModel.Option] = []
	for i in range(option_data_list.size()):
		var option_data = option_data_list[i]
		var option_path = _path_index(_path_join(path, KEY_OPTIONS), i)
		if not (option_data is Dictionary):
			push_error("%s must be a Dictionary; got %s" % [option_path, str(typeof(option_data))])
			continue
		options.append(compile_option(option_data, option_path))
	return WeavlyModel.OptionBlock.new(options)


static func compile_option(data: Dictionary, path: String) -> WeavlyModel.Option:
	var condition_data = get_required(data, KEY_CONDITION, Variant.Type.TYPE_NIL, path)
	var condition = compile_expression(condition_data, _path_join(path, KEY_CONDITION))
	var text = get_required(data, KEY_TEXT, Variant.Type.TYPE_STRING, path)
	var body_data_list = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	var body = compile_statements(body_data_list, _path_join(path, KEY_BODY))
	var hint = get_required(data, KEY_HINT, Variant.Type.TYPE_BOOL, path)
	return WeavlyModel.Option.new(condition, text, body, hint)


# =====================
# Option Block
# =====================


static func compile_random_block(data: Dictionary, path: String) -> WeavlyModel.RandomBlock:
	var case_data_list = get_required(data, KEY_CASES, Variant.Type.TYPE_ARRAY, path)
	var cases: Array[WeavlyModel.RandomCase] = []
	for i in range(case_data_list.size()):
		var case_data = case_data_list[i]
		var case_path = _path_index(_path_join(path, KEY_CASES), i)
		if not (case_data is Dictionary):
			push_error("%s must be a Dictionary; got %s" % [case_path, str(typeof(case_data))])
			continue
		cases.append(compile_random_case(case_data, case_path))
	return WeavlyModel.RandomBlock.new(cases)


static func compile_random_case(data: Dictionary, path: String) -> WeavlyModel.RandomCase:
	var condition_data = get_required(data, KEY_CONDITION, Variant.Type.TYPE_NIL, path)
	var condition = compile_expression(condition_data, _path_join(path, KEY_CONDITION))
	var weight_data = get_required(data, KEY_WEIGHT, Variant.Type.TYPE_NIL, path)
	var weight = compile_expression(weight_data, _path_join(path, KEY_WEIGHT))
	var body_data_list = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	var body = compile_statements(body_data_list, _path_join(path, KEY_BODY))
	return WeavlyModel.RandomCase.new(condition, weight, body)


# =====================
# Expressions
# =====================


static func compile_expression(data: Variant, path: String) -> WeavlyModel.WeavlyExpression:
	if data is bool:
		return WeavlyModel.TrueExpression.new() if data else WeavlyModel.FalseExpression.new()

	if data is int or data is float:
		return WeavlyModel.Number.new(float(data))

	if data is String:
		return WeavlyModel.StringLiteral.new(String(data))

	if data is Dictionary and data.has(KEY_VARIABLE):
		var variable = get_required(data, KEY_VARIABLE, Variant.Type.TYPE_STRING, path)
		return WeavlyModel.Identifier.new(variable)

	if data is Dictionary and data.has(KEY_EXPRESSION):
		var op = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		var expression_data = get_required(data, KEY_EXPRESSION, Variant.Type.TYPE_NIL, path)
		var expression = compile_expression(expression_data, _path_join(path, KEY_EXPRESSION))
		return WeavlyModel.UnaryExpression.new(op, expression)

	if data is Dictionary and data.has(KEY_LEFT) and data.has(KEY_RIGHT):
		var op = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		var left_data = get_required(data, KEY_LEFT, Variant.Type.TYPE_NIL, path)
		var right_data = get_required(data, KEY_RIGHT, Variant.Type.TYPE_NIL, path)
		var left = compile_expression(left_data, _path_join(path, KEY_LEFT))
		var right = compile_expression(right_data, _path_join(path, KEY_RIGHT))
		return WeavlyModel.BinaryExpression.new(op, left, right)

	push_error("Unknown expression type at %s: %s" % [path, str(data)])
	return null


# =====================
# Variables
# =====================


static func compile_variable_declarations(data: Variant) -> Array[WeavlyModel.Variable]:
	var variables: Array[WeavlyModel.Variable]
	for variable_data in data.get(KEY_DECLARATIONS):
		var variable = compile_variable(variable_data)
		if variable != null:
			variables.append(variable)
	return variables


static func compile_variable(data: Variant) -> WeavlyModel.Variable:
	var id = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING)

	if data is Dictionary and data.get(KEY_TYPE) == TYPE_NUMBER:
		var value: float = get_required(data, KEY_VALUE, Variant.Type.TYPE_FLOAT)
		var min = data.get(KEY_MIN, null)
		var max = data.get(KEY_MAX, null)
		return WeavlyModel.NumberVariable.new(id, value, min, max)

	if data is Dictionary and data.get(KEY_TYPE) == TYPE_STRING:
		var value: String = get_required(data, KEY_VALUE, Variant.Type.TYPE_STRING)
		return WeavlyModel.StringVariable.new(id, value)

	if data is Dictionary and data.get(KEY_TYPE) == TYPE_FLAG:
		var value: bool = get_required(data, KEY_VALUE, Variant.Type.TYPE_BOOL)
		return WeavlyModel.FlagVariable.new(id, value)

	push_error("Unknown variable type: %s" % str(data))
	return null


static func compile_variable_from_value(id: StringName, value: Variant) -> WeavlyModel.Variable:
	if value is float:
		return WeavlyModel.NumberVariable.new(id, 0, null, null)
	if value is String:
		return WeavlyModel.StringVariable.new(id, "")
	if value is bool:
		return WeavlyModel.FlagVariable.new(id, false)

	push_error("Unknown variable value: %s" % type_string(typeof(value)))
	return null
