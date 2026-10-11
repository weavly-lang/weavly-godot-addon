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
const KEY_SLOTS = "slots"
const KEY_CHARACTERS = "characters"
const KEY_META_KEYS = "meta_keys"
const KEY_FUNCTIONS = "functions"

# Common keys
const KEY_ID = "id"
const KEY_SPEAKER = "speaker"
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
const KEY_KEY = "key"
const KEY_CHARACTER = "character"

# Meta keys
const KEY_META = "meta"
const KEY_POOL = "pool"
const KEY_SLOT = "slot"
const KEY_WHEN = "when"
const KEY_PRIORITY = "priority"
const KEY_AVAILABLE = "available"
const KEY_LABEL = "label"
const KEY_LABEL_UNAVAILABLE = "label_unavailable"
const KEY_LABEL_TEASER = "label_teaser"

# Block keys
const KEY_CASES = "cases"
const KEY_OPTIONS = "items"
const KEY_LIMIT = "limit"
const KEY_SHUFFLE = "shuffle"
const KEY_LOCKED = "locked"

# Variable keys
const KEY_NAME = "name"
const KEY_VALUE = "value"
const KEY_MIN = "min"
const KEY_MAX = "max"
const KEY_EXTERN = "extern"
const KEY_PARAMS = "params"
const KEY_RETURNS = "returns"

# Type values
const TYPE_NARRATION = "narration"
const TYPE_CHARACTER = "character"
const TYPE_MATCH = "match"
const TYPE_OPTION = "option"
const TYPE_SET = "set"
const TYPE_JUMP = "jump"
const TYPE_DETOUR = "detour"
const TYPE_FINISH = "finish"
const TYPE_DO = "do"
const TYPE_NUMBER = "number"
const TYPE_STRING = "string"
const TYPE_BOOL = "bool"
const TYPE_NODE = "node"
const TYPE_POOL = "pool"
const TYPE_SLOT = "slot"
const TYPE_RANDOM = "random"
const TYPE_DRAW = "draw"
const TYPE_INLINE = "inline"

const LOCKED_MODES: Dictionary[String, WeavlyEngine.Locked] = {
	"show": WeavlyEngine.Locked.SHOW,
	"extra": WeavlyEngine.Locked.EXTRA,
	"hide": WeavlyEngine.Locked.HIDE,
}

# Variable type -> its zero value, which also gives the Variant type of its values.
const VARIABLE_DEFAULTS: Dictionary[String, Variant] = {
	TYPE_NUMBER: 0.0,
	TYPE_STRING: "",
	TYPE_BOOL: false,
	TYPE_NODE: "",
	TYPE_POOL: "",
	TYPE_SLOT: "",
	TYPE_CHARACTER: "",
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


# Appends each read item to into. A failing item is dropped, or with strict
# fails the whole list, which then returns false.
static func _read_list(
	items: Array, path: String, read: Callable, into: Array, strict: bool = true
) -> bool:
	for i: int in range(items.size()):
		var item: Variant = read.call(items[i], _path_index(path, i))
		if item != null:
			into.append(item)
		elif strict:
			return false
	return true


# Reports anything but a Dictionary at path.
static func _is_dictionary(data: Variant, path: String) -> bool:
	if data is Dictionary:
		return true
	push_error("%s must be a Dictionary, got %s" % [path, type_string(typeof(data))])
	return false


# For items read from a Dictionary that carries a line.
static func _read_located(data: Variant, path: String, read: Callable) -> Variant:
	if not _is_dictionary(data, path):
		return null
	var line: Variant = _get_required_line(data, path)
	var item: Variant = read.call(data, path)
	if line == null or item == null:
		return null
	item.line = line
	return item


# =====================
# Nodes
# =====================


static func read_nodes(data: Dictionary, source: String = "") -> Array[WeavlyModel.WeavlyNode]:
	var nodes_data: Variant = get_required(data, KEY_NODES, Variant.Type.TYPE_ARRAY, source)
	var source_name: Variant = get_required(data, KEY_SOURCE, Variant.Type.TYPE_STRING, source)
	var nodes: Array[WeavlyModel.WeavlyNode] = []
	if nodes_data == null or source_name == null:
		return nodes
	var read: Callable = _read_located.bind(read_node)
	_read_list(nodes_data, _path_root(source, KEY_NODES), read, nodes, false)
	for node: WeavlyModel.WeavlyNode in nodes:
		node.source = source_name
		_set_source(node.body, source_name)
	return nodes


# Sets source on the statements and every statement nested in them.
static func _set_source(statements: Array[WeavlyModel.Statement], source: String) -> void:
	for statement: WeavlyModel.Statement in statements:
		statement.source = source
		if statement is WeavlyModel.MatchBlock:
			for case: WeavlyModel.WhenCase in statement.cases:
				_set_source(case.body, source)
		elif statement is WeavlyModel.RandomBlock:
			for case: WeavlyModel.RandomCase in statement.cases:
				_set_source(case.body, source)
		elif statement is WeavlyModel.OptionBlock:
			for item: WeavlyModel.OptionItem in statement.items:
				if item is WeavlyModel.InlineOptionItem:
					_set_source(item.body, source)


static func read_node(data: Dictionary, path: String) -> WeavlyModel.WeavlyNode:
	var id: Variant = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var body: Variant = read_body(data, path)
	var meta: WeavlyModel.NodeMeta = null
	if data.has(KEY_META):
		meta = read_meta(data[KEY_META], _path_join(path, KEY_META))
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


static func read_meta(data: Variant, path: String) -> WeavlyModel.NodeMeta:
	if not _is_dictionary(data, path):
		return null
	var meta: WeavlyModel.NodeMeta = WeavlyModel.NodeMeta.new()
	for key: Variant in data:
		var entry_path: String = _path_join(path, str(key))
		var entry: Variant = data[key]
		if not _is_dictionary(entry, entry_path):
			return null
		if not _read_meta_entry(meta, key, entry, entry_path):
			return null
	return meta


static func _read_meta_entry(
	meta: WeavlyModel.NodeMeta, key: Variant, entry: Dictionary, path: String
) -> bool:
	if key == KEY_POOL or key == KEY_SLOT:
		var names_data: Variant = get_required(entry, KEY_VALUE, Variant.Type.TYPE_ARRAY, path)
		var names: Array[String] = meta.pools if key == KEY_POOL else meta.slots
		var value_path: String = _path_join(path, KEY_VALUE)
		return names_data != null and _read_list(names_data, value_path, _read_name, names)
	var line: Variant = _get_required_line(entry, path)
	var expression: WeavlyModel.WeavlyExpression = read_required_expression(entry, KEY_VALUE, path)
	if line == null or expression == null:
		return false
	meta.entries[key] = WeavlyModel.MetaExpression.new(expression, line)
	return true


static func _read_name(data: Variant, path: String) -> Variant:
	if data is String:
		return data
	push_error("%s must be a String, got %s" % [path, type_string(typeof(data))])
	return null


# =====================
# Statements
# =====================


# Null when the body is missing; a failing statement inside it is dropped.
static func read_body(data: Dictionary, path: String) -> Variant:
	var body_data: Variant = get_required(data, KEY_BODY, Variant.Type.TYPE_ARRAY, path)
	if body_data == null:
		return null
	return read_statements(body_data, _path_join(path, KEY_BODY))


static func read_statements(data: Array, path: String) -> Array[WeavlyModel.Statement]:
	var statements: Array[WeavlyModel.Statement] = []
	var read: Callable = _read_located.bind(read_statement)
	_read_list(data, path, read, statements, false)
	return statements


static func read_statement(data: Dictionary, path: String) -> WeavlyModel.Statement:
	var type: Variant = get_required(data, KEY_TYPE, Variant.Type.TYPE_STRING, path)
	if type == null:
		return null

	match type:
		TYPE_NARRATION:
			return read_narration_line(data, path)
		TYPE_CHARACTER:
			return read_character_line(data, path)
		TYPE_MATCH:
			return read_match_block(data, path)
		TYPE_OPTION:
			return read_option_block(data, path)
		TYPE_SET:
			return read_set_statement(data, path)
		TYPE_JUMP:
			return read_jump_statement(data, path)
		TYPE_DETOUR:
			return read_detour_statement(data, path)
		TYPE_FINISH:
			return read_finish_statement(data, path)
		TYPE_DO:
			return read_do_statement(data, path)
		TYPE_RANDOM:
			return read_random_block(data, path)
		TYPE_DRAW:
			return read_draw_statement(data, path)
		_:
			push_error("Unknown statement type '%s' at %s" % [type, path])
			return null


static func read_narration_line(data: Dictionary, path: String) -> WeavlyModel.NarrationLine:
	var segments: Variant = read_text(data, path)
	if segments == null:
		return null
	return WeavlyModel.NarrationLine.new(segments)


# A one-off speaker is a string or a text; a character arrives as {"character": ...}.
static func read_character_line(data: Dictionary, path: String) -> WeavlyModel.CharacterLine:
	var speaker: WeavlyModel.WeavlyExpression = read_required_expression(data, KEY_SPEAKER, path)
	var segments: Variant = read_text(data, path)
	if speaker == null or segments == null:
		return null
	return WeavlyModel.CharacterLine.new(speaker, segments)


static func read_set_statement(data: Dictionary, path: String) -> WeavlyModel.SetStatement:
	var id: Variant = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	if id == null:
		return null
	var expression: WeavlyModel.WeavlyExpression = read_required_expression(
		data, KEY_EXPRESSION, path
	)
	if expression == null:
		return null
	return WeavlyModel.SetStatement.new(id, expression)


static func read_jump_statement(data: Dictionary, path: String) -> WeavlyModel.JumpStatement:
	var target: WeavlyModel.WeavlyExpression = _read_required_target(data, KEY_ID, path)
	return null if target == null else WeavlyModel.JumpStatement.new(target)


static func read_detour_statement(data: Dictionary, path: String) -> WeavlyModel.DetourStatement:
	var target: WeavlyModel.WeavlyExpression = _read_required_target(data, KEY_ID, path)
	return null if target == null else WeavlyModel.DetourStatement.new(target)


static func read_draw_statement(data: Dictionary, path: String) -> WeavlyModel.DrawStatement:
	var pools: Variant = _read_targets(data, KEY_POOLS, path)
	return null if pools == null else WeavlyModel.DrawStatement.new(pools)


# A name as a StringLiteral, or {"variable": ...} as an Identifier.
static func _read_target(data: Variant, path: String) -> WeavlyModel.WeavlyExpression:
	if data is String or (data is Dictionary and data.has(KEY_VARIABLE)):
		return read_expression(data, path)
	push_error("%s must be a name or a variable, got %s" % [path, str(data)])
	return null


static func _read_required_target(
	data: Dictionary, key: String, path: String
) -> WeavlyModel.WeavlyExpression:
	var target: Variant = get_required(data, key, Variant.Type.TYPE_NIL, path)
	return null if target == null else _read_target(target, _path_join(path, key))


# Null when the list is missing or any target fails.
static func _read_targets(data: Dictionary, key: String, path: String) -> Variant:
	var targets_data: Variant = get_required(data, key, Variant.Type.TYPE_ARRAY, path)
	if targets_data == null:
		return null
	var targets: Array[WeavlyModel.WeavlyExpression] = []
	if not _read_list(targets_data, _path_join(path, key), _read_target, targets):
		return null
	return targets


static func read_finish_statement(_data: Dictionary, _path: String) -> WeavlyModel.FinishStatement:
	return WeavlyModel.FinishStatement.new()


static func read_do_statement(data: Dictionary, path: String) -> WeavlyModel.DoStatement:
	var id: Variant = get_required(data, KEY_ID, Variant.Type.TYPE_STRING, path)
	var args: Variant = read_arguments(data, path)
	if id == null or args == null:
		return null
	return WeavlyModel.DoStatement.new(id, args)


# Strings are plain text, anything else is an interpolated expression.
static func read_text(data: Dictionary, path: String) -> Variant:
	var text_data: Variant = get_required(data, KEY_TEXT, Variant.Type.TYPE_ARRAY, path)
	if text_data == null:
		return null
	var segments: Array = []
	if not _read_list(text_data, _path_join(path, KEY_TEXT), _read_segment, segments):
		return null
	return segments


static func _read_segment(data: Variant, path: String) -> Variant:
	if data is String:
		return data
	return read_expression(data, path)


# =====================
# Match Block
# =====================


static func read_match_block(data: Dictionary, path: String) -> WeavlyModel.MatchBlock:
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
	var read: Callable = _read_located.bind(read_when_case)
	if not _read_list(cases_data, _path_join(path, KEY_CASES), read, cases):
		return null
	return WeavlyModel.MatchBlock.new(modifier, cases)


static func read_when_case(data: Dictionary, path: String) -> WeavlyModel.WhenCase:
	var condition: WeavlyModel.WeavlyExpression = read_required_expression(
		data, KEY_CONDITION, path
	)
	var body: Variant = read_body(data, path)
	if condition == null or body == null:
		return null
	return WeavlyModel.WhenCase.new(condition, body)


# =====================
# Option Block
# =====================


static func read_option_block(data: Dictionary, path: String) -> WeavlyModel.OptionBlock:
	var items_data: Variant = get_required(data, KEY_OPTIONS, Variant.Type.TYPE_ARRAY, path)
	if items_data == null:
		return null
	var items: Array[WeavlyModel.OptionItem] = []
	var read: Callable = _read_located.bind(read_option_item)
	if not _read_list(items_data, _path_join(path, KEY_OPTIONS), read, items):
		return null
	return WeavlyModel.OptionBlock.new(items)


static func read_option_item(data: Dictionary, path: String) -> WeavlyModel.OptionItem:
	var type: Variant = get_required(data, KEY_TYPE, Variant.Type.TYPE_STRING, path)
	match type:
		null:
			return null
		TYPE_INLINE:
			return _read_inline_option(data, path)
		TYPE_NODE:
			var node: WeavlyModel.WeavlyExpression = _read_required_target(data, KEY_ID, path)
			return null if node == null else WeavlyModel.NodeOptionItem.new(node)
		TYPE_POOL:
			return _read_pool_option(data, path)
	push_error("Unknown option type '%s' at %s" % [type, path])
	return null


static func _read_inline_option(data: Dictionary, path: String) -> WeavlyModel.OptionItem:
	var meta: Variant = get_required(data, KEY_META, Variant.Type.TYPE_DICTIONARY, path)
	var body: Variant = read_body(data, path)
	if meta == null or body == null:
		return null
	var meta_path: String = _path_join(path, KEY_META)
	for key: Variant in meta:
		if key != KEY_LABEL and key != KEY_WHEN:
			push_error("Unknown option meta key '%s' at %s" % [key, meta_path])
			return null
	var label_entry: Variant = get_required(
		meta, KEY_LABEL, Variant.Type.TYPE_DICTIONARY, meta_path
	)
	if label_entry == null:
		return null
	var label: WeavlyModel.WeavlyExpression = read_required_expression(
		label_entry, KEY_VALUE, _path_join(meta_path, KEY_LABEL)
	)
	var condition: WeavlyModel.WeavlyExpression = WeavlyModel.TrueExpression.new()
	if meta.has(KEY_WHEN):
		var entry: Variant = get_required(meta, KEY_WHEN, Variant.Type.TYPE_DICTIONARY, meta_path)
		if entry == null:
			return null
		condition = read_required_expression(entry, KEY_VALUE, _path_join(meta_path, KEY_WHEN))
	if label == null or condition == null:
		return null
	return WeavlyModel.InlineOptionItem.new(condition, label, body)


static func _read_pool_option(data: Dictionary, path: String) -> WeavlyModel.OptionItem:
	var pools: Variant = _read_targets(data, KEY_POOLS, path)
	var locked_name: Variant = get_required(data, KEY_LOCKED, Variant.Type.TYPE_STRING, path)
	var shuffle: WeavlyModel.WeavlyExpression = read_required_expression(data, KEY_SHUFFLE, path)
	if pools == null or locked_name == null or shuffle == null:
		return null
	if not data.has(KEY_LIMIT):
		push_error("Missing required field '%s' at %s" % [KEY_LIMIT, path])
		return null
	var limit: WeavlyModel.WeavlyExpression = null
	if data[KEY_LIMIT] != null:
		limit = read_expression(data[KEY_LIMIT], _path_join(path, KEY_LIMIT))
		if limit == null:
			return null
	if locked_name not in LOCKED_MODES:
		push_error("Unknown locked mode '%s' at %s" % [locked_name, path])
		return null
	return WeavlyModel.PoolOptionItem.new(pools, limit, shuffle, LOCKED_MODES[locked_name])


# =====================
# Random Block
# =====================


static func read_random_block(data: Dictionary, path: String) -> WeavlyModel.RandomBlock:
	var cases_data: Variant = get_required(data, KEY_CASES, Variant.Type.TYPE_ARRAY, path)
	if cases_data == null:
		return null
	var cases: Array[WeavlyModel.RandomCase] = []
	var read: Callable = _read_located.bind(read_random_case)
	if not _read_list(cases_data, _path_join(path, KEY_CASES), read, cases):
		return null
	return WeavlyModel.RandomBlock.new(cases)


static func read_random_case(data: Dictionary, path: String) -> WeavlyModel.RandomCase:
	var condition: WeavlyModel.WeavlyExpression = read_required_expression(
		data, KEY_CONDITION, path
	)
	var weight: WeavlyModel.WeavlyExpression = read_required_expression(data, KEY_WEIGHT, path)
	var body: Variant = read_body(data, path)
	if condition == null or weight == null or body == null:
		return null
	return WeavlyModel.RandomCase.new(condition, weight, body)


# =====================
# Expressions
# =====================


# Null when the field is missing or its expression fails; either is reported once.
static func read_required_expression(
	data: Dictionary, key: String, path: String
) -> WeavlyModel.WeavlyExpression:
	var expression_data: Variant = get_required(data, key, Variant.Type.TYPE_NIL, path)
	if expression_data == null:
		return null
	return read_expression(expression_data, _path_join(path, key))


# Null when args is missing or any argument fails.
static func read_arguments(data: Dictionary, path: String) -> Variant:
	var args_data: Variant = get_required(data, KEY_ARGS, Variant.Type.TYPE_ARRAY, path)
	if args_data == null:
		return null
	var args: Array[WeavlyModel.WeavlyExpression] = []
	if not _read_list(args_data, _path_join(path, KEY_ARGS), read_expression, args):
		return null
	return args


static func read_expression(data: Variant, path: String) -> WeavlyModel.WeavlyExpression:
	if data is bool:
		return WeavlyModel.TrueExpression.new() if data else WeavlyModel.FalseExpression.new()

	if data is int or data is float:
		return WeavlyModel.Number.new(float(data))

	if data is String:
		return WeavlyModel.StringLiteral.new(String(data))

	if data is Dictionary and data.has(KEY_CALL):
		return read_call(data, path)

	if data is Dictionary and data.has(KEY_TEXT):
		var segments: Variant = read_text(data, path)
		return null if segments == null else WeavlyModel.TextExpression.new(segments)

	if data is Dictionary and data.has(KEY_CHARACTER):
		var character: WeavlyModel.WeavlyExpression = read_required_expression(
			data, KEY_CHARACTER, path
		)
		return null if character == null else WeavlyModel.CharacterName.new(character)

	if data is Dictionary and data.has(KEY_VARIABLE):
		var variable: Variant = get_required(data, KEY_VARIABLE, Variant.Type.TYPE_STRING, path)
		if variable == null:
			return null
		return WeavlyModel.Identifier.new(variable)

	if data is Dictionary and data.has(KEY_EXPRESSION):
		var op: Variant = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		if op == null:
			return null
		var expression: WeavlyModel.WeavlyExpression = read_required_expression(
			data, KEY_EXPRESSION, path
		)
		if expression == null:
			return null
		return WeavlyModel.UnaryExpression.new(op, expression)

	if data is Dictionary and data.has(KEY_LEFT) and data.has(KEY_RIGHT):
		var op: Variant = get_required(data, KEY_OP, Variant.Type.TYPE_STRING, path)
		if op == null:
			return null
		var left: WeavlyModel.WeavlyExpression = read_required_expression(data, KEY_LEFT, path)
		var right: WeavlyModel.WeavlyExpression = read_required_expression(data, KEY_RIGHT, path)
		if left == null or right == null:
			return null
		return WeavlyModel.BinaryExpression.new(op, left, right)

	push_error("Unknown expression type at %s: %s" % [path, str(data)])
	return null


static func read_call(data: Dictionary, path: String) -> WeavlyModel.WeavlyExpression:
	var name: Variant = get_required(data, KEY_CALL, Variant.Type.TYPE_STRING, path)
	if name == null:
		return null
	if WeavlyExpressionEvaluator.is_number_function(name):
		return _read_number_call(name, data, path)
	if name == WeavlyExpressionEvaluator.META:
		return _read_meta_call(data, path)
	if name not in WeavlyExpressionEvaluator.NODE_FUNCTIONS:
		var args: Variant = read_arguments(data, path)
		return null if args == null else WeavlyModel.Call.new(name, null, args)
	var node: WeavlyModel.WeavlyExpression = _read_required_target(data, KEY_NODE, path)
	return null if node == null else WeavlyModel.Call.new(name, node)


static func _read_meta_call(data: Dictionary, path: String) -> WeavlyModel.MetaCall:
	var node: WeavlyModel.WeavlyExpression = _read_required_target(data, KEY_NODE, path)
	var key: Variant = get_required(data, KEY_KEY, Variant.Type.TYPE_STRING, path)
	if node == null or key == null:
		return null
	return WeavlyModel.MetaCall.new(node, key)


static func _read_number_call(name: String, data: Dictionary, path: String) -> WeavlyModel.Call:
	var args: Variant = read_arguments(data, path)
	if args == null:
		return null
	var count_error: String = WeavlyExpressionEvaluator.argument_count_error(name, args.size())
	if count_error != "":
		push_error("%s at %s" % [count_error, path])
		return null
	return WeavlyModel.Call.new(name, null, args)


# =====================
# Variables
# =====================


static func read_variable_declarations(
	data: Variant, source: String = ""
) -> Array[WeavlyModel.Variable]:
	var variables: Array[WeavlyModel.Variable] = []
	var declarations: Variant = get_required(
		data, KEY_DECLARATIONS, Variant.Type.TYPE_ARRAY, source
	)
	if declarations == null:
		return variables
	var path: String = _path_root(source, KEY_DECLARATIONS)
	_read_list(declarations, path, read_variable, variables, false)
	return variables


# The pool names declared in env.json.
static func read_pool_names(data: Dictionary, source: String = "") -> Array[String]:
	return _read_names(data, KEY_POOLS, source)


# The slot names declared in env.json.
static func read_slot_names(data: Dictionary, source: String = "") -> Array[String]:
	return _read_names(data, KEY_SLOTS, source)


# The character names declared in env.json.
static func read_character_names(data: Dictionary, source: String = "") -> Array[String]:
	return _read_names(data, KEY_CHARACTERS, source)


# The declared custom meta keys in env.json, each with its default.
static func read_meta_keys(data: Dictionary, source: String = "") -> Dictionary[String, Variant]:
	var keys: Dictionary[String, Variant] = {}
	var keys_data: Variant = get_required(data, KEY_META_KEYS, Variant.Type.TYPE_ARRAY, source)
	if keys_data == null:
		return keys
	var declared: Array = []
	_read_list(keys_data, _path_root(source, KEY_META_KEYS), _read_meta_key, declared, false)
	for key: Array in declared:
		keys[key[0]] = key[1]
	return keys


# [name, default], or null.
static func _read_meta_key(data: Variant, path: String) -> Variant:
	if not _is_dictionary(data, path):
		return null
	var name: Variant = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING, path)
	var type: Variant = get_required(data, KEY_TYPE, Variant.Type.TYPE_STRING, path)
	if name == null or type == null:
		return null
	if type not in VARIABLE_DEFAULTS:
		push_error("Unknown meta key type '%s' at %s" % [type, path])
		return null
	var expected: Variant.Type = typeof(VARIABLE_DEFAULTS[type]) as Variant.Type
	var value: Variant = get_required(data, KEY_VALUE, expected, path)
	if value == null:
		return null
	return [name, value]


# The declared functions in env.json.
static func read_functions(data: Dictionary, source: String = "") -> Array[WeavlyModel.Signature]:
	var signatures: Array[WeavlyModel.Signature] = []
	var signatures_data: Variant = get_required(
		data, KEY_FUNCTIONS, Variant.Type.TYPE_ARRAY, source
	)
	if signatures_data != null:
		var path: String = _path_root(source, KEY_FUNCTIONS)
		_read_list(signatures_data, path, _read_signature, signatures, false)
	return signatures


# A function without returns has an empty return type.
static func _read_signature(data: Variant, path: String) -> WeavlyModel.Signature:
	if not _is_dictionary(data, path):
		return null
	var name: Variant = get_required(data, KEY_NAME, Variant.Type.TYPE_STRING, path)
	var params: Variant = get_required(data, KEY_PARAMS, Variant.Type.TYPE_ARRAY, path)
	var returns: bool = data.has(KEY_RETURNS)
	var return_type: Variant = (
		get_required(data, KEY_RETURNS, Variant.Type.TYPE_STRING, path) if returns else ""
	)
	if name == null or params == null or return_type == null:
		return null
	var read_params: Array = []
	if not _read_list(params, _path_join(path, KEY_PARAMS), _read_param, read_params):
		return null
	if returns and not _is_value_type(return_type, _path_join(path, KEY_RETURNS)):
		return null
	var param_types: Array[String] = []
	var variable_params: Array[bool] = []
	for param: Array in read_params:
		param_types.append(param[0])
		variable_params.append(param[1])
	return WeavlyModel.Signature.new(name, param_types, return_type, variable_params)


# [type, whether it's a var parameter], or null.
static func _read_param(data: Variant, path: String) -> Variant:
	if not _is_dictionary(data, path):
		return null
	var type: Variant = get_required(data, KEY_TYPE, Variant.Type.TYPE_STRING, path)
	var variable: Variant = (
		get_required(data, KEY_VARIABLE, Variant.Type.TYPE_BOOL, path)
		if data.has(KEY_VARIABLE)
		else false
	)
	if type == null or variable == null or not _is_value_type(type, path):
		return null
	return [type, variable]


static func _is_value_type(type: String, path: String) -> bool:
	if type in VARIABLE_DEFAULTS:
		return true
	push_error("Unknown type '%s' at %s" % [type, path])
	return false


static func _read_names(data: Dictionary, key: String, source: String) -> Array[String]:
	var names: Array[String] = []
	var names_data: Variant = get_required(data, key, Variant.Type.TYPE_ARRAY, source)
	if names_data != null:
		_read_list(names_data, _path_root(source, key), _read_name, names, false)
	return names


static func read_variable(data: Variant, path: String = "") -> WeavlyModel.Variable:
	if path == "":
		path = "<root>"

	if not _is_dictionary(data, path):
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
		TYPE_BOOL:
			variable = WeavlyModel.BoolVariable.new(id, value)
		TYPE_NODE, TYPE_POOL, TYPE_SLOT, TYPE_CHARACTER:
			variable = WeavlyModel.NameVariable.new(id, type, value)
	variable.extern = extern
	return variable
