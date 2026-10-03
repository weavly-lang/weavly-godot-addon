@tool
class_name WeavlySymbolResolver
extends RefCounted

enum Block { NONE, ENV, BODY, META }

const NAME_KINDS: Array[WeavlyProjectIndex.Kind] = [
	WeavlyProjectIndex.Kind.NODE, WeavlyProjectIndex.Kind.POOL, WeavlyProjectIndex.Kind.SLOT
]

static var _node_regex: RegEx = RegEx.create_from_string("^\\s*@node\\b")
static var _end_node_regex: RegEx = RegEx.create_from_string("^\\s*@endnode\\b")
static var _env_regex: RegEx = RegEx.create_from_string("^\\s*@env\\b")
static var _end_env_regex: RegEx = RegEx.create_from_string("^\\s*@endenv\\b")
static var _meta_regex: RegEx = RegEx.create_from_string("^\\s*@meta\\b")
static var _end_meta_regex: RegEx = RegEx.create_from_string("^\\s*@endmeta\\b")
static var _meta_entry_regex: RegEx = RegEx.create_from_string("^\\s*([A-Za-z_]\\w*)\\s*:")
static var _name_value_regex: RegEx = RegEx.create_from_string("\\b(node|pool|slot)\\s*=\\s*$")
static var _node_target_regex: RegEx = RegEx.create_from_string(
	"(@jump\\s+|@detour\\s+|->\\s*|@option\\s+node\\s*\\(\\s*)$"
)
static var _draw_regex: RegEx = RegEx.create_from_string("@draw\\s+[\\w\\s,]*$")
static var _pool_option_regex: RegEx = RegEx.create_from_string("@option\\s+pool\\s*\\([^()]*$")
static var _pool_argument_regex: RegEx = RegEx.create_from_string("[(,]\\s*$")
static var _option_keyword_regex: RegEx = RegEx.create_from_string("@option\\s+$")


class Symbol:
	extends RefCounted
	var name: String
	var kinds: Array[WeavlyProjectIndex.Kind] = []


# The name at the position and what it can refer to, or null outside code.
static func resolve(lines: PackedStringArray, line: int, column: int) -> Symbol:
	if line < 0 or line >= lines.size():
		return null
	var text: String = lines[line]
	var start: int = column
	if not _is_word_char(text, start) and _is_word_char(text, start - 1):
		start -= 1
	if not _is_word_char(text, start):
		return null
	while _is_word_char(text, start - 1):
		start -= 1
	var end: int = start
	while _is_word_char(text, end):
		end += 1
	if text[start] >= "0" and text[start] <= "9":
		return null

	var block: Block = block_at(lines, line)
	if code_mask(text, block)[start] == 0:
		return null
	var kinds: Array[WeavlyProjectIndex.Kind] = _kinds(text, start, end, block)
	if kinds.is_empty():
		return null
	var symbol: Symbol = Symbol.new()
	symbol.name = text.substr(start, end - start)
	symbol.kinds = kinds
	return symbol


# The block the line sits in, from the lines above it.
static func block_at(lines: PackedStringArray, line: int) -> Block:
	var block: Block = Block.NONE
	for i: int in line:
		var text: String = lines[i]
		if block == Block.ENV:
			if _end_env_regex.search(text) != null:
				block = Block.NONE
		elif block == Block.META:
			if _end_meta_regex.search(text) != null:
				block = Block.BODY
		elif _env_regex.search(text) != null:
			block = Block.ENV
		elif _node_regex.search(text) != null:
			block = Block.BODY
		elif block == Block.BODY and _meta_regex.search(text) != null:
			block = Block.META
		elif _end_node_regex.search(text) != null:
			block = Block.NONE
	return block


# 1 for each character of code; dialogue text, strings and comments are 0, except inside {}.
static func code_mask(text: String, block: Block) -> PackedByteArray:
	var mask: PackedByteArray = []
	mask.resize(text.length())
	if block == Block.BODY:
		_mask_line(text, 0, mask)
	elif block != Block.NONE:
		_mask_code(text, 0, mask, false)
	return mask


# A body line, or the part after an inline action's colon.
static func _mask_line(text: String, from: int, mask: PackedByteArray) -> void:
	var i: int = from
	while i < text.length() and text[i] in " \t":
		i += 1
	if i >= text.length() or text[i] == "#":
		return
	if text[i] == "@" or text.substr(i, 2) == "->":
		var colon: int = _mask_code(text, i, mask, true)
		if colon >= 0:
			_mask_line(text, colon + 1, mask)
	elif text[i] == "$":
		var colon: int = _mask_code(text, i, mask, true)
		if colon >= 0:
			_mask_text(text, colon + 1, mask)
	elif text[i] == ">":
		var colon: int = text.find(":", i)
		if colon >= 0:
			_mask_text(text, colon + 1, mask)
	else:
		_mask_text(text, i, mask)


# Returns the first colon outside brackets when stopping there, else -1.
static func _mask_code(text: String, from: int, mask: PackedByteArray, stop_at_colon: bool) -> int:
	var depth: int = 0
	var i: int = from
	while i < text.length():
		var c: String = text[i]
		if c == '"':
			i = _mask_string(text, i, mask)
			continue
		if c == "#":
			return -1
		if c == ":" and depth == 0 and stop_at_colon:
			return i
		if c in "([":
			depth += 1
		elif c in ")]":
			depth = maxi(depth - 1, 0)
		mask[i] = 1
		i += 1
	return -1


# Returns the index after the closing quote.
static func _mask_string(text: String, from: int, mask: PackedByteArray) -> int:
	var i: int = from + 1
	while i < text.length() and text[i] != '"':
		if text[i] == "\\":
			i += 2
		elif text[i] == "{":
			i = _mask_interpolation(text, i, mask)
		else:
			i += 1
	return i + 1


static func _mask_text(text: String, from: int, mask: PackedByteArray) -> void:
	var i: int = from
	while i < text.length():
		if text[i] == "\\":
			i += 2
		elif text[i] == "{":
			i = _mask_interpolation(text, i, mask)
		else:
			i += 1


# Returns the index after the closing brace.
static func _mask_interpolation(text: String, from: int, mask: PackedByteArray) -> int:
	var i: int = from + 1
	var quoted: bool = false
	while i < text.length() and (quoted or text[i] != "}"):
		if text[i] == '"':
			quoted = not quoted
		elif not quoted:
			mask[i] = 1
		i += 1
	return i + 1


static func _kinds(
	text: String, start: int, end: int, block: Block
) -> Array[WeavlyProjectIndex.Kind]:
	var before: String = text.substr(0, start)
	var after: String = text.substr(end).strip_edges(true, false)
	if before.ends_with("$"):
		return [WeavlyProjectIndex.Kind.VARIABLE]
	if before.ends_with("@"):
		if block != Block.BODY:
			return []
		return [WeavlyProjectIndex.Kind.COMMAND]
	if block == Block.ENV:
		var value: RegExMatch = _name_value_regex.search(before)
		if value == null:
			return []
		return [_group_kind(value.get_string(1))]
	if block == Block.META:
		var entry: RegExMatch = _meta_entry_regex.search(text)
		if entry == null:
			return []
		if start < entry.get_end(1):
			return [WeavlyProjectIndex.Kind.META_KEY]
		var key: String = entry.get_string(1)
		if key == "pool" or key == "slot":
			return [_group_kind(key)]
		return _expression_kinds(before, after)
	if _node_target_regex.search(before) != null:
		return [WeavlyProjectIndex.Kind.NODE]
	if _draw_regex.search(before) != null:
		return [WeavlyProjectIndex.Kind.POOL]
	if _pool_option_regex.search(before) != null:
		if after.begins_with(":"):
			return []
		if (
			_pool_argument_regex.search(before) != null
			and (after.begins_with(",") or after.begins_with(")"))
		):
			return [WeavlyProjectIndex.Kind.POOL]
	return _expression_kinds(before, after)


static func _expression_kinds(before: String, after: String) -> Array[WeavlyProjectIndex.Kind]:
	if not after.begins_with("("):
		return NAME_KINDS.duplicate()
	if _option_keyword_regex.search(before) != null:
		return []
	return [WeavlyProjectIndex.Kind.FUNCTION]


static func _group_kind(word: String) -> WeavlyProjectIndex.Kind:
	match word:
		"pool":
			return WeavlyProjectIndex.Kind.POOL
		"slot":
			return WeavlyProjectIndex.Kind.SLOT
	return WeavlyProjectIndex.Kind.NODE


static func _is_word_char(text: String, index: int) -> bool:
	if index < 0 or index >= text.length():
		return false
	var c: String = text[index]
	return (
		c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")
	)
