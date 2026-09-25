class_name WeavlyDeserializer
extends RefCounted

# =====================
# Field Keys
# =====================

# Top-level keys
const KEY_NODES = "nodes"
const KEY_DECLARATIONS = "declarations"
const KEY_SOURCE = "source"

# Common keys
const KEY_ID = "id"
const KEY_NAME_IS_ID = "name_is_id"
const KEY_BODY = "body"
const KEY_TYPE = "type"
const KEY_TEXT = "text"
const KEY_WEIGHT = "weight"
const KEY_MODIFIER = "modifier"
const KEY_LINE = "line"

# Expression keys
const KEY_EXPRESSION = "expression"
const KEY_CONDITION = "condition"
const KEY_VARIABLE = "variable"
const KEY_OP = "op"
const KEY_LEFT = "left"
const KEY_RIGHT = "right"
const KEY_CALL = "call"
const KEY_NODE = "node"
const KEY_ARGS = "args"

# Block keys
const KEY_CASES = "cases"
const KEY_OPTIONS = "items"
const KEY_HINT = "hint"

# Variable keys
const KEY_NAME = "name"
const KEY_VALUE = "value"
const KEY_MIN = "min"
const KEY_MAX = "max"
const KEY_EXTERN = "extern"

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


static func _path_root(source: String, key: String) -> String:
	return "%s > %s" % [source, key] if source != "" else key


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


static func _get_required_line(data: Dictionary, path: String) -> Variant:
	var line: Variant = get_required(data, KEY_LINE, Variant.Type.TYPE_FLOAT, path)
	return null if line == null else int(line)


# =====================
# Nodes
# =====================


static func compile_nodes(data: Dictionary, source: String = "") -> Array[WeavlyModel.WeavlyNode]:
	var nodes_arr = get_required(data, KEY_NODES, Variant.Type.TYPE_ARRAY, source)
	var source_name: Variant = get_required(data, KEY_SOURCE, Variant.Type.TYPE_STRING, source)
	var nodes: Array[WeavlyModel.WeavlyNode] = []
	if nodes_arr == null or source_name == null:
		return nodes
	for i in range(nodes_arr.size()):
		var node_data = nodes_arr[i]
		var node_path = _path_index(_path_root(source, KEY_NODES), i)
		if not (node_data is Dictionary):
			push_error("%s must be a Dictionary, got %s" % [node_path, str(typeof(node_data))])
			continue
		var node = compile_node(node_data, node_path)
		if node != null:
			node.source = source_name
			nodes.append(node)
	return nodes


static func compile_node(data: Dictionary, path: String) -> WeavlyModel.WeavlyNode:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var line: Variant = _get_required_line(data, path)
	var body_arr = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	if id == null or line == null or body_arr == null:
		return null
	var body = compile_statements(body_arr, _path_join(path, KEY_BODY))
	var node: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new(id, body)
	node.line = line
	return node


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
		var statement_path: String = _path_index(path, i)
		var line: Variant = _get_required_line(statement, statement_path)
		var compiled = compile_statement(statement, statement_path)
		if compiled != null and line != null:
			compiled.line = line
			statements.append(compiled)
	return statements


static func compile_statement(data: Dictionary, path: String) -> WeavlyModel.Statement:
	var type = get_required(data, KEY_TYPE, Variant.Type.TYPE_STRING, path)
	if type == null:
		return null

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
	var segments: Variant = compile_text(data, path)
	if segments == null:
		return null
	return WeavlyModel.NarrationLine.new(segments)


static func compile_character_line(data: Dictionary, path: String) -> WeavlyModel.CharacterLine:
	var name = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING, path)
	var name_is_id = get_required(data, KEY_NAME_IS_ID, Variant.Type.TYPE_BOOL, path)
	var segments: Variant = compile_text(data, path)
	if name == null or name_is_id == null or segments == null:
		return null
	return WeavlyModel.CharacterLine.new(name, name_is_id, segments)


static func compile_set_statement(data: Dictionary, path: String) -> WeavlyModel.SetStatement:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	if id == null:
		return null
	var expr = compile_required_expression(data, KEY_EXPRESSION, path)
	if expr == null:
		return null
	return WeavlyModel.SetStatement.new(id, expr)


static func compile_goto_statement(data: Dictionary, path: String) -> WeavlyModel.GotoStatement:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	if id == null:
		return null
	return WeavlyModel.GotoStatement.new(id)


static func compile_finish_statement(
	_data: Dictionary, _path: String
) -> WeavlyModel.FinishStatement:
	return WeavlyModel.FinishStatement.new()


static func compile_command_statement(
	data: Dictionary, path: String
) -> WeavlyModel.CommandStatement:
	var id = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var args_data = get_required(data, KEY_ARGS, Variant.Type.TYPE_ARRAY, path)
	if id == null or args_data == null:
		return null
	var args: Array[WeavlyModel.WeavlyExpression] = []
	for i in range(args_data.size()):
		var arg = compile_expression(args_data[i], _path_index(_path_join(path, KEY_ARGS), i))
		if arg == null:
			return null
		args.append(arg)
	return WeavlyModel.CommandStatement.new(id, args)


# Strings are plain text, anything else is an interpolated expression.
static func compile_text(data: Dictionary, path: String) -> Variant:
	var text_data: Variant = get_required(data, KEY_TEXT, Variant.Type.TYPE_ARRAY, path)
	if text_data == null:
		return null
	var segments: Array = []
	for i in range(text_data.size()):
		var segment: Variant = text_data[i]
		if segment is String:
			segments.append(segment)
			continue
		var expression: WeavlyModel.WeavlyExpression = compile_expression(
			segment, _path_index(_path_join(path, KEY_TEXT), i)
		)
		if expression == null:
			return null
		segments.append(expression)
	return segments


# =====================
# Match Block
# =====================


static func compile_match_block(data: Dictionary, path: String) -> WeavlyModel.MatchBlock:
	var modifier_string = get_required(data, KEY_MODIFIER, Variant.Type.TYPE_STRING, path)
	var case_data_list = get_required(data, KEY_CASES, Variant.Type.TYPE_ARRAY, path)
	if modifier_string == null or case_data_list == null:
		return null

	var modifier: WeavlyModel.MatchModifier
	match modifier_string:
		"first":
			modifier = WeavlyModel.MatchModifier.FIRST
		"last":
			modifier = WeavlyModel.MatchModifier.LAST
		"all":
			modifier = WeavlyModel.MatchModifier.ALL
		_:
			push_error("Unknown match modifier '%s' at %s" % [modifier_string, path])
			return null

	var cases: Array[WeavlyModel.WhenCase] = []
	for i in range(case_data_list.size()):
		var case_data = case_data_list[i]
		var case_path = _path_index(_path_join(path, KEY_CASES), i)
		if not (case_data is Dictionary):
			push_error("%s must be a Dictionary; got %s" % [case_path, str(typeof(case_data))])
			return null
		var when_case = compile_when_case(case_data, case_path)
		if when_case == null:
			return null
		cases.append(when_case)

	return WeavlyModel.MatchBlock.new(modifier, cases)


static func compile_when_case(data: Dictionary, path: String) -> WeavlyModel.WhenCase:
	var line: Variant = _get_required_line(data, path)
	var condition = compile_required_expression(data, KEY_CONDITION, path)
	var body_data_list = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	if line == null or condition == null or body_data_list == null:
		return null
	var body = compile_statements(body_data_list, _path_join(path, KEY_BODY))
	var when_case: WeavlyModel.WhenCase = WeavlyModel.WhenCase.new(condition, body)
	when_case.line = line
	return when_case


# =====================
# Option Block
# =====================


static func compile_option_block(data: Dictionary, path: String) -> WeavlyModel.OptionBlock:
	var option_data_list = get_required(data, KEY_OPTIONS, Variant.Type.TYPE_ARRAY, path)
	var options: Array[WeavlyModel.Option] = []
	if option_data_list == null:
		return null
	for i in range(option_data_list.size()):
		var option_data = option_data_list[i]
		var option_path = _path_index(_path_join(path, KEY_OPTIONS), i)
		if not (option_data is Dictionary):
			push_error("%s must be a Dictionary; got %s" % [option_path, str(typeof(option_data))])
			return null
		var option = compile_option(option_data, option_path)
		if option == null:
			return null
		options.append(option)
	return WeavlyModel.OptionBlock.new(options)


static func compile_option(data: Dictionary, path: String) -> WeavlyModel.Option:
	var line: Variant = _get_required_line(data, path)
	var condition = compile_required_expression(data, KEY_CONDITION, path)
	var segments: Variant = compile_text(data, path)
	var body_data_list = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	var hint = get_required(data, KEY_HINT, Variant.Type.TYPE_BOOL, path)
	if (
		line == null
		or condition == null
		or segments == null
		or body_data_list == null
		or hint == null
	):
		return null
	var body = compile_statements(body_data_list, _path_join(path, KEY_BODY))
	var option: WeavlyModel.Option = WeavlyModel.Option.new(condition, segments, body, hint)
	option.line = line
	return option


# =====================
# Random Block
# =====================


static func compile_random_block(data: Dictionary, path: String) -> WeavlyModel.RandomBlock:
	var case_data_list = get_required(data, KEY_CASES, Variant.Type.TYPE_ARRAY, path)
	var cases: Array[WeavlyModel.RandomCase] = []
	if case_data_list == null:
		return null
	for i in range(case_data_list.size()):
		var case_data = case_data_list[i]
		var case_path = _path_index(_path_join(path, KEY_CASES), i)
		if not (case_data is Dictionary):
			push_error("%s must be a Dictionary; got %s" % [case_path, str(typeof(case_data))])
			return null
		var random_case = compile_random_case(case_data, case_path)
		if random_case == null:
			return null
		cases.append(random_case)
	return WeavlyModel.RandomBlock.new(cases)


static func compile_random_case(data: Dictionary, path: String) -> WeavlyModel.RandomCase:
	var line: Variant = _get_required_line(data, path)
	var condition = compile_required_expression(data, KEY_CONDITION, path)
	var weight = compile_required_expression(data, KEY_WEIGHT, path)
	var body_data_list = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	if line == null or condition == null or weight == null or body_data_list == null:
		return null
	var body = compile_statements(body_data_list, _path_join(path, KEY_BODY))
	var random_case: WeavlyModel.RandomCase = WeavlyModel.RandomCase.new(condition, weight, body)
	random_case.line = line
	return random_case


# =====================
# Expressions
# =====================


# Null when the field is missing or its expression fails; either is reported once.
static func compile_required_expression(
	data: Dictionary, key: String, path: String
) -> WeavlyModel.WeavlyExpression:
	var expression_data = get_required(data, key, Variant.Type.TYPE_NIL, path)
	if expression_data == null:
		return null
	return compile_expression(expression_data, _path_join(path, key))


static func compile_expression(data: Variant, path: String) -> WeavlyModel.WeavlyExpression:
	if data is bool:
		return WeavlyModel.TrueExpression.new() if data else WeavlyModel.FalseExpression.new()

	if data is int or data is float:
		return WeavlyModel.Number.new(float(data))

	if data is String:
		return WeavlyModel.StringLiteral.new(String(data))

	if data is Dictionary and data.has(KEY_CALL):
		return compile_call(data, path)

	if data is Dictionary and data.has(KEY_VARIABLE):
		var variable = get_required(data, KEY_VARIABLE, Variant.Type.TYPE_STRING, path)
		if variable == null:
			return null
		return WeavlyModel.Identifier.new(variable)

	if data is Dictionary and data.has(KEY_EXPRESSION):
		var op = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		if op == null:
			return null
		var expression = compile_required_expression(data, KEY_EXPRESSION, path)
		if expression == null:
			return null
		return WeavlyModel.UnaryExpression.new(op, expression)

	if data is Dictionary and data.has(KEY_LEFT) and data.has(KEY_RIGHT):
		var op = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		if op == null:
			return null
		var left = compile_required_expression(data, KEY_LEFT, path)
		var right = compile_required_expression(data, KEY_RIGHT, path)
		if left == null or right == null:
			return null
		return WeavlyModel.BinaryExpression.new(op, left, right)

	push_error("Unknown expression type at %s: %s" % [path, str(data)])
	return null


static func compile_call(data: Dictionary, path: String) -> WeavlyModel.Call:
	var name = get_required(data, KEY_CALL, Variant.Type.TYPE_STRING, path)
	if name == null:
		return null
	if WeavlyExpressionEvaluator.is_number_function(name):
		return _compile_number_call(name, data, path)
	if name not in WeavlyExpressionEvaluator.NODE_FUNCTIONS:
		push_error("Unknown function '%s' at %s" % [name, path])
		return null
	var node_id = get_required(data, KEY_NODE, Variant.Type.TYPE_STRING, path)
	if node_id == null:
		return null
	return WeavlyModel.Call.new(name, node_id)


static func _compile_number_call(name: String, data: Dictionary, path: String) -> WeavlyModel.Call:
	var args_data = get_required(data, KEY_ARGS, Variant.Type.TYPE_ARRAY, path)
	if args_data == null:
		return null
	var count_error: String = WeavlyExpressionEvaluator.argument_count_error(
		name, args_data.size()
	)
	if count_error != "":
		push_error("%s at %s" % [count_error, path])
		return null
	var args: Array[WeavlyModel.WeavlyExpression] = []
	for i in range(args_data.size()):
		var arg = compile_expression(args_data[i], _path_index(_path_join(path, KEY_ARGS), i))
		if arg == null:
			return null
		args.append(arg)
	return WeavlyModel.Call.new(name, "", args)


# =====================
# Variables
# =====================


static func compile_variable_declarations(
	data: Variant, source: String = ""
) -> Array[WeavlyModel.Variable]:
	var variables: Array[WeavlyModel.Variable]
	var declarations = get_required(data, KEY_DECLARATIONS, Variant.Type.TYPE_ARRAY, source)
	if declarations == null:
		return variables
	for i in range(declarations.size()):
		var declaration_path = _path_index(_path_root(source, KEY_DECLARATIONS), i)
		var variable = compile_variable(declarations[i], declaration_path)
		if variable != null:
			variables.append(variable)
	return variables


static func compile_variable(data: Variant, path: String = "") -> WeavlyModel.Variable:
	if path == "":
		path = "<root>"

	if not (data is Dictionary):
		push_error(
			"Variable declaration at %s must be a Dictionary, got %s" % [path, str(typeof(data))]
		)
		return null

	var id = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING, path)
	if id == null:
		return null

	if data.get(KEY_EXTERN, false) == true:
		return _compile_extern_declaration(data, id, path)

	if data is Dictionary and data.get(KEY_TYPE) == TYPE_NUMBER:
		var value: Variant = get_required(data, KEY_VALUE, Variant.Type.TYPE_FLOAT, path)
		if value == null:
			return null
		var min = data.get(KEY_MIN, null)
		var max = data.get(KEY_MAX, null)
		return WeavlyModel.NumberVariable.new(id, value, min, max)

	if data is Dictionary and data.get(KEY_TYPE) == TYPE_STRING:
		var value: Variant = get_required(data, KEY_VALUE, Variant.Type.TYPE_STRING, path)
		if value == null:
			return null
		return WeavlyModel.StringVariable.new(id, value)

	if data is Dictionary and data.get(KEY_TYPE) == TYPE_FLAG:
		var value: Variant = get_required(data, KEY_VALUE, Variant.Type.TYPE_BOOL, path)
		if value == null:
			return null
		return WeavlyModel.FlagVariable.new(id, value)

	push_error("Unknown variable type at %s: %s" % [path, str(data)])
	return null


static func _compile_extern_declaration(
	data: Dictionary, id: String, path: String
) -> WeavlyModel.Variable:
	var variable: WeavlyModel.Variable
	match data.get(KEY_TYPE):
		TYPE_NUMBER:
			variable = WeavlyModel.NumberVariable.new(id, 0.0, null, null)
		TYPE_STRING:
			variable = WeavlyModel.StringVariable.new(id, "")
		TYPE_FLAG:
			variable = WeavlyModel.FlagVariable.new(id, false)
		_:
			push_error("Unknown variable type at %s: %s" % [path, str(data)])
			return null
	variable.extern = true
	return variable
