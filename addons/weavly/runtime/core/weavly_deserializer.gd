class_name WeavlyDeserializer
extends RefCounted

# =====================
# Field Keys
# =====================

# Top-level keys
const KEY_NODES = "nodes"
const KEY_DECLARATIONS = "declarations"
const KEY_SOURCE = "source"
const KEY_POOLS = "pools"

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

# Meta keys
const KEY_META = "meta"
const KEY_POOL = "pool"
const KEY_SLOT = "slot"
const KEY_WHEN = "when"
const KEY_PRIORITY = "priority"

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
const TYPE_DRAW = "draw"

# Variable type -> value an extern starts with; its type is the declared value's type.
const VARIABLE_DEFAULTS: Dictionary[String, Variant] = {
	TYPE_NUMBER: 0.0,
	TYPE_STRING: "",
	TYPE_FLAG: false,
}

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

	var value: Variant = data.get(key)
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


# Appends each compiled item to into. A failing item is dropped, or with strict
# fails the whole list, which then returns false.
static func _compile_list(
	items: Array, path: String, compile: Callable, into: Array, strict: bool = true
) -> bool:
	for i: int in range(items.size()):
		var compiled: Variant = compile.call(items[i], _path_index(path, i))
		if compiled != null:
			into.append(compiled)
		elif strict:
			return false
	return true


# For items compiled from a Dictionary that carries a line.
static func _compile_located(data: Variant, path: String, compile: Callable) -> Variant:
	if data is not Dictionary:
		push_error("%s must be a Dictionary, got %s" % [path, type_string(typeof(data))])
		return null
	var line: Variant = _get_required_line(data, path)
	var compiled: Variant = compile.call(data, path)
	if line == null or compiled == null:
		return null
	compiled.line = line
	return compiled


# =====================
# Nodes
# =====================


static func compile_nodes(data: Dictionary, source: String = "") -> Array[WeavlyModel.WeavlyNode]:
	var nodes_data: Variant = get_required(data, KEY_NODES, Variant.Type.TYPE_ARRAY, source)
	var source_name: Variant = get_required(data, KEY_SOURCE, Variant.Type.TYPE_STRING, source)
	var nodes: Array[WeavlyModel.WeavlyNode] = []
	if nodes_data == null or source_name == null:
		return nodes
	var compile: Callable = _compile_located.bind(compile_node)
	_compile_list(nodes_data, _path_root(source, KEY_NODES), compile, nodes, false)
	for node: WeavlyModel.WeavlyNode in nodes:
		node.source = source_name
	return nodes


static func compile_node(data: Dictionary, path: String) -> WeavlyModel.WeavlyNode:
	var id: Variant = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var body: Variant = compile_body(data, path)
	var meta: WeavlyModel.NodeMeta = null
	if data.has(KEY_META):
		meta = compile_meta(data[KEY_META], _path_join(path, KEY_META))
		if meta == null:
			return null
	if id == null or body == null:
		return null
	var node: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new(id, body)
	node.meta = meta
	return node


# =====================
# Meta
# =====================


static func compile_meta(data: Variant, path: String) -> WeavlyModel.NodeMeta:
	if data is not Dictionary:
		push_error("%s must be a Dictionary, got %s" % [path, type_string(typeof(data))])
		return null
	var meta: WeavlyModel.NodeMeta = WeavlyModel.NodeMeta.new()
	for key: Variant in data:
		var entry_path: String = _path_join(path, str(key))
		var entry: Variant = data[key]
		if entry is not Dictionary:
			push_error(
				"%s must be a Dictionary, got %s" % [entry_path, type_string(typeof(entry))]
			)
			return null
		if not _compile_meta_entry(meta, key, entry, entry_path):
			return null
	return meta


static func _compile_meta_entry(
	meta: WeavlyModel.NodeMeta, key: Variant, entry: Dictionary, path: String
) -> bool:
	var value_path: String = _path_join(path, KEY_VALUE)
	match key:
		KEY_POOL, KEY_SLOT:
			var names_data: Variant = get_required(entry, KEY_VALUE, Variant.Type.TYPE_ARRAY, path)
			var names: Array[String] = meta.pools if key == KEY_POOL else meta.slots
			return (
				names_data != null and _compile_list(names_data, value_path, _compile_name, names)
			)
		KEY_WHEN, KEY_PRIORITY, KEY_WEIGHT:
			var line: Variant = _get_required_line(entry, path)
			var expression: WeavlyModel.WeavlyExpression = compile_required_expression(
				entry, KEY_VALUE, path
			)
			if line == null or expression == null:
				return false
			meta.set(key, WeavlyModel.MetaExpression.new(expression, line))
			return true
	push_error("Unknown meta key '%s' at %s" % [key, path])
	return false


static func _compile_name(data: Variant, path: String) -> Variant:
	if data is String:
		return data
	push_error("%s must be a String, got %s" % [path, type_string(typeof(data))])
	return null


# =====================
# Statements
# =====================


# Null when the body is missing; a failing statement inside it is dropped.
static func compile_body(data: Dictionary, path: String) -> Variant:
	var body_data: Variant = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	if body_data == null:
		return null
	return compile_statements(body_data, _path_join(path, KEY_BODY))


static func compile_statements(data: Array, path: String) -> Array[WeavlyModel.Statement]:
	var statements: Array[WeavlyModel.Statement] = []
	var compile: Callable = _compile_located.bind(compile_statement)
	_compile_list(data, path, compile, statements, false)
	return statements


static func compile_statement(data: Dictionary, path: String) -> WeavlyModel.Statement:
	var type: Variant = get_required(data, KEY_TYPE, Variant.Type.TYPE_STRING, path)
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
		TYPE_DRAW:
			return compile_draw_statement(data, path)
		_:
			push_error("Unknown statement type '%s' at %s" % [type, path])
			return null


static func compile_narration_line(data: Dictionary, path: String) -> WeavlyModel.NarrationLine:
	var segments: Variant = compile_text(data, path)
	if segments == null:
		return null
	return WeavlyModel.NarrationLine.new(segments)


static func compile_character_line(data: Dictionary, path: String) -> WeavlyModel.CharacterLine:
	var name: Variant = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING, path)
	var name_is_id: Variant = get_required(data, KEY_NAME_IS_ID, Variant.Type.TYPE_BOOL, path)
	var segments: Variant = compile_text(data, path)
	if name == null or name_is_id == null or segments == null:
		return null
	return WeavlyModel.CharacterLine.new(name, name_is_id, segments)


static func compile_set_statement(data: Dictionary, path: String) -> WeavlyModel.SetStatement:
	var id: Variant = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	if id == null:
		return null
	var expression: WeavlyModel.WeavlyExpression = compile_required_expression(
		data, KEY_EXPRESSION, path
	)
	if expression == null:
		return null
	return WeavlyModel.SetStatement.new(id, expression)


static func compile_goto_statement(data: Dictionary, path: String) -> WeavlyModel.GotoStatement:
	var id: Variant = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	if id == null:
		return null
	return WeavlyModel.GotoStatement.new(id)


static func compile_draw_statement(data: Dictionary, path: String) -> WeavlyModel.DrawStatement:
	var pools_data: Variant = get_required(data, KEY_POOLS, Variant.Type.TYPE_ARRAY, path)
	if pools_data == null:
		return null
	var pools: Array[String] = []
	if not _compile_list(pools_data, _path_join(path, KEY_POOLS), _compile_name, pools):
		return null
	return WeavlyModel.DrawStatement.new(pools)


static func compile_finish_statement(
	_data: Dictionary, _path: String
) -> WeavlyModel.FinishStatement:
	return WeavlyModel.FinishStatement.new()


static func compile_command_statement(
	data: Dictionary, path: String
) -> WeavlyModel.CommandStatement:
	var id: Variant = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var args: Variant = compile_arguments(data, path)
	if id == null or args == null:
		return null
	return WeavlyModel.CommandStatement.new(id, args)


# Strings are plain text, anything else is an interpolated expression.
static func compile_text(data: Dictionary, path: String) -> Variant:
	var text_data: Variant = get_required(data, KEY_TEXT, Variant.Type.TYPE_ARRAY, path)
	if text_data == null:
		return null
	var segments: Array = []
	if not _compile_list(text_data, _path_join(path, KEY_TEXT), _compile_segment, segments):
		return null
	return segments


static func _compile_segment(data: Variant, path: String) -> Variant:
	if data is String:
		return data
	return compile_expression(data, path)


# =====================
# Match Block
# =====================


static func compile_match_block(data: Dictionary, path: String) -> WeavlyModel.MatchBlock:
	var modifier_name: Variant = get_required(data, KEY_MODIFIER, Variant.Type.TYPE_STRING, path)
	var cases_data: Variant = get_required(data, KEY_CASES, Variant.Type.TYPE_ARRAY, path)
	if modifier_name == null or cases_data == null:
		return null

	var modifier: WeavlyModel.MatchModifier
	match modifier_name:
		"first":
			modifier = WeavlyModel.MatchModifier.FIRST
		"last":
			modifier = WeavlyModel.MatchModifier.LAST
		"all":
			modifier = WeavlyModel.MatchModifier.ALL
		_:
			push_error("Unknown match modifier '%s' at %s" % [modifier_name, path])
			return null

	var cases: Array[WeavlyModel.WhenCase] = []
	var compile: Callable = _compile_located.bind(compile_when_case)
	if not _compile_list(cases_data, _path_join(path, KEY_CASES), compile, cases):
		return null
	return WeavlyModel.MatchBlock.new(modifier, cases)


static func compile_when_case(data: Dictionary, path: String) -> WeavlyModel.WhenCase:
	var condition: WeavlyModel.WeavlyExpression = compile_required_expression(
		data, KEY_CONDITION, path
	)
	var body: Variant = compile_body(data, path)
	if condition == null or body == null:
		return null
	return WeavlyModel.WhenCase.new(condition, body)


# =====================
# Option Block
# =====================


static func compile_option_block(data: Dictionary, path: String) -> WeavlyModel.OptionBlock:
	var options_data: Variant = get_required(data, KEY_OPTIONS, Variant.Type.TYPE_ARRAY, path)
	if options_data == null:
		return null
	var options: Array[WeavlyModel.Option] = []
	var compile: Callable = _compile_located.bind(compile_option)
	if not _compile_list(options_data, _path_join(path, KEY_OPTIONS), compile, options):
		return null
	return WeavlyModel.OptionBlock.new(options)


static func compile_option(data: Dictionary, path: String) -> WeavlyModel.Option:
	var condition: WeavlyModel.WeavlyExpression = compile_required_expression(
		data, KEY_CONDITION, path
	)
	var segments: Variant = compile_text(data, path)
	var body: Variant = compile_body(data, path)
	var hint: Variant = get_required(data, KEY_HINT, Variant.Type.TYPE_BOOL, path)
	if condition == null or segments == null or body == null or hint == null:
		return null
	return WeavlyModel.Option.new(condition, segments, body, hint)


# =====================
# Random Block
# =====================


static func compile_random_block(data: Dictionary, path: String) -> WeavlyModel.RandomBlock:
	var cases_data: Variant = get_required(data, KEY_CASES, Variant.Type.TYPE_ARRAY, path)
	if cases_data == null:
		return null
	var cases: Array[WeavlyModel.RandomCase] = []
	var compile: Callable = _compile_located.bind(compile_random_case)
	if not _compile_list(cases_data, _path_join(path, KEY_CASES), compile, cases):
		return null
	return WeavlyModel.RandomBlock.new(cases)


static func compile_random_case(data: Dictionary, path: String) -> WeavlyModel.RandomCase:
	var condition: WeavlyModel.WeavlyExpression = compile_required_expression(
		data, KEY_CONDITION, path
	)
	var weight: WeavlyModel.WeavlyExpression = compile_required_expression(data, KEY_WEIGHT, path)
	var body: Variant = compile_body(data, path)
	if condition == null or weight == null or body == null:
		return null
	return WeavlyModel.RandomCase.new(condition, weight, body)


# =====================
# Expressions
# =====================


# Null when the field is missing or its expression fails; either is reported once.
static func compile_required_expression(
	data: Dictionary, key: String, path: String
) -> WeavlyModel.WeavlyExpression:
	var expression_data: Variant = get_required(data, key, Variant.Type.TYPE_NIL, path)
	if expression_data == null:
		return null
	return compile_expression(expression_data, _path_join(path, key))


# Null when args is missing or any argument fails.
static func compile_arguments(data: Dictionary, path: String) -> Variant:
	var args_data: Variant = get_required(data, KEY_ARGS, Variant.Type.TYPE_ARRAY, path)
	if args_data == null:
		return null
	var args: Array[WeavlyModel.WeavlyExpression] = []
	if not _compile_list(args_data, _path_join(path, KEY_ARGS), compile_expression, args):
		return null
	return args


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
		var variable: Variant = get_required(data, KEY_VARIABLE, Variant.Type.TYPE_STRING, path)
		if variable == null:
			return null
		return WeavlyModel.Identifier.new(variable)

	if data is Dictionary and data.has(KEY_EXPRESSION):
		var op: Variant = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		if op == null:
			return null
		var expression: WeavlyModel.WeavlyExpression = compile_required_expression(
			data, KEY_EXPRESSION, path
		)
		if expression == null:
			return null
		return WeavlyModel.UnaryExpression.new(op, expression)

	if data is Dictionary and data.has(KEY_LEFT) and data.has(KEY_RIGHT):
		var op: Variant = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		if op == null:
			return null
		var left: WeavlyModel.WeavlyExpression = compile_required_expression(data, KEY_LEFT, path)
		var right: WeavlyModel.WeavlyExpression = compile_required_expression(
			data, KEY_RIGHT, path
		)
		if left == null or right == null:
			return null
		return WeavlyModel.BinaryExpression.new(op, left, right)

	push_error("Unknown expression type at %s: %s" % [path, str(data)])
	return null


static func compile_call(data: Dictionary, path: String) -> WeavlyModel.Call:
	var name: Variant = get_required(data, KEY_CALL, Variant.Type.TYPE_STRING, path)
	if name == null:
		return null
	if WeavlyExpressionEvaluator.is_number_function(name):
		return _compile_number_call(name, data, path)
	if name not in WeavlyExpressionEvaluator.NODE_FUNCTIONS:
		push_error("Unknown function '%s' at %s" % [name, path])
		return null
	var node_id: Variant = get_required(data, KEY_NODE, Variant.Type.TYPE_STRING, path)
	if node_id == null:
		return null
	return WeavlyModel.Call.new(name, node_id)


static func _compile_number_call(name: String, data: Dictionary, path: String) -> WeavlyModel.Call:
	var args_data: Variant = get_required(data, KEY_ARGS, Variant.Type.TYPE_ARRAY, path)
	if args_data == null:
		return null
	var count_error: String = WeavlyExpressionEvaluator.argument_count_error(
		name, args_data.size()
	)
	if count_error != "":
		push_error("%s at %s" % [count_error, path])
		return null
	var args: Variant = compile_arguments(data, path)
	if args == null:
		return null
	return WeavlyModel.Call.new(name, "", args)


# =====================
# Variables
# =====================


static func compile_variable_declarations(
	data: Variant, source: String = ""
) -> Array[WeavlyModel.Variable]:
	var variables: Array[WeavlyModel.Variable] = []
	var declarations: Variant = get_required(
		data, KEY_DECLARATIONS, Variant.Type.TYPE_ARRAY, source
	)
	if declarations == null:
		return variables
	var path: String = _path_root(source, KEY_DECLARATIONS)
	_compile_list(declarations, path, compile_variable, variables, false)
	return variables


# The pool names declared in env.json.
static func compile_pool_names(data: Dictionary, source: String = "") -> Array[String]:
	var names: Array[String] = []
	var names_data: Variant = get_required(data, KEY_POOLS, Variant.Type.TYPE_ARRAY, source)
	if names_data != null:
		_compile_list(names_data, _path_root(source, KEY_POOLS), _compile_name, names, false)
	return names


static func compile_variable(data: Variant, path: String = "") -> WeavlyModel.Variable:
	if path == "":
		path = "<root>"

	if data is not Dictionary:
		push_error(
			(
				"Variable declaration at %s must be a Dictionary, got %s"
				% [path, type_string(typeof(data))]
			)
		)
		return null

	var id: Variant = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING, path)
	if id == null:
		return null

	var type: Variant = data.get(KEY_TYPE)
	if type not in VARIABLE_DEFAULTS:
		push_error("Unknown variable type at %s: %s" % [path, str(data)])
		return null

	var extern: bool = data.get(KEY_EXTERN, false) == true
	var default: Variant = VARIABLE_DEFAULTS[type]
	var value: Variant = (
		default if extern else get_required(data, KEY_VALUE, typeof(default) as Variant.Type, path)
	)
	if value == null:
		return null

	var variable: WeavlyModel.Variable
	match type:
		TYPE_NUMBER:
			variable = WeavlyModel.NumberVariable.new(
				id, value, data.get(KEY_MIN), data.get(KEY_MAX)
			)
		TYPE_STRING:
			variable = WeavlyModel.StringVariable.new(id, value)
		TYPE_FLAG:
			variable = WeavlyModel.FlagVariable.new(id, value)
	variable.extern = extern
	return variable
