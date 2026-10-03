@tool
class_name WeavlySymbolResolver
extends RefCounted

const NAME_KINDS: Array[WeavlyProjectIndex.Kind] = [
	WeavlyProjectIndex.Kind.NODE, WeavlyProjectIndex.Kind.POOL, WeavlyProjectIndex.Kind.SLOT
]

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

	var block: WeavlyLineScanner.Block = WeavlyLineScanner.block_at(lines, line)
	if block == WeavlyLineScanner.Block.NONE:
		return null
	if WeavlyLineScanner.parts(text, block)[start] != WeavlyLineScanner.Part.CODE:
		return null
	var kinds: Array[WeavlyProjectIndex.Kind] = _kinds(text, start, end, block)
	if kinds.is_empty():
		return null
	var symbol: Symbol = Symbol.new()
	symbol.name = text.substr(start, end - start)
	symbol.kinds = kinds
	return symbol


static func _kinds(
	text: String, start: int, end: int, block: WeavlyLineScanner.Block
) -> Array[WeavlyProjectIndex.Kind]:
	var before: String = text.substr(0, start)
	var after: String = text.substr(end).strip_edges(true, false)
	if before.ends_with("$"):
		return [WeavlyProjectIndex.Kind.VARIABLE]
	if before.ends_with("@"):
		if block != WeavlyLineScanner.Block.BODY:
			return []
		return [WeavlyProjectIndex.Kind.COMMAND]
	if block == WeavlyLineScanner.Block.ENV:
		var value: RegExMatch = _name_value_regex.search(before)
		if value == null:
			return []
		return [_group_kind(value.get_string(1))]
	if block == WeavlyLineScanner.Block.META:
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
