@tool
class_name WeavlySymbolResolver
extends RefCounted

enum Role { USE, DECLARATION, MEMBERSHIP }

# Names share one namespace, so a bare name can be any of these.
const NAME_KINDS: Array[WeavlyProjectIndex.Kind] = [
	WeavlyProjectIndex.Kind.NODE,
	WeavlyProjectIndex.Kind.POOL,
	WeavlyProjectIndex.Kind.SLOT,
	WeavlyProjectIndex.Kind.CHARACTER,
	WeavlyProjectIndex.Kind.VARIABLE,
]
const SPEAKER_KINDS: Array[WeavlyProjectIndex.Kind] = [
	WeavlyProjectIndex.Kind.CHARACTER, WeavlyProjectIndex.Kind.VARIABLE
]
# Targets also take a variable of their type.
const NODE_TARGET_KINDS: Array[WeavlyProjectIndex.Kind] = [
	WeavlyProjectIndex.Kind.NODE, WeavlyProjectIndex.Kind.VARIABLE
]
const POOL_TARGET_KINDS: Array[WeavlyProjectIndex.Kind] = [
	WeavlyProjectIndex.Kind.POOL, WeavlyProjectIndex.Kind.VARIABLE
]

static var _meta_entry_regex: RegEx = RegEx.create_from_string("^\\s*([A-Za-z_]\\w*)\\s*:")
static var _name_value_regex: RegEx = RegEx.create_from_string(
	"\\b(node|pool|slot|character)\\s*=\\s*$"
)
static var _node_target_regex: RegEx = RegEx.create_from_string(
	"(@jump\\s+|@detour\\s+|@option\\s+node\\s*\\(\\s*)$"
)
static var _draw_regex: RegEx = RegEx.create_from_string("@draw\\s+[\\w\\s,]*$")
static var _pool_option_regex: RegEx = RegEx.create_from_string("@option\\s+pool\\s*\\([^()]*$")
static var _pool_argument_regex: RegEx = RegEx.create_from_string("[(,]\\s*$")
static var _option_keyword_regex: RegEx = RegEx.create_from_string("@option\\s+$")
static var _var_argument_regex: RegEx = RegEx.create_from_string("[(,]\\s*var\\s+$")


class Symbol:
	extends RefCounted
	var name: String
	var kinds: Array[WeavlyProjectIndex.Kind] = []
	var role: Role = Role.USE
	var column: int


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
	var block: WeavlyLineScanner.Block = WeavlyLineScanner.block_at(lines, line)
	return _symbol(text, block, WeavlyLineScanner.parts(text, block), start)


# Every name on the line that resolves, in order.
static func symbols(text: String, block: WeavlyLineScanner.Block) -> Array[Symbol]:
	var found: Array[Symbol] = []
	var parts: PackedByteArray = WeavlyLineScanner.parts(text, block)
	var start: int = 0
	while start < text.length():
		if not _is_word_char(text, start):
			start += 1
			continue
		var symbol: Symbol = _symbol(text, block, parts, start)
		if symbol != null:
			found.append(symbol)
		while _is_word_char(text, start):
			start += 1
	return found


static func _symbol(
	text: String, block: WeavlyLineScanner.Block, parts: PackedByteArray, start: int
) -> Symbol:
	var end: int = start
	while _is_word_char(text, end):
		end += 1
	if text[start] >= "0" and text[start] <= "9":
		return null
	var symbol: Symbol = Symbol.new()
	symbol.name = text.substr(start, end - start)
	symbol.column = start
	var declared: int = _declared_kind(text, block, start)
	if declared != -1:
		symbol.kinds = [declared]
		symbol.role = Role.DECLARATION
		return symbol
	if block == WeavlyLineScanner.Block.NONE:
		return null
	match parts[start]:
		WeavlyLineScanner.Part.CODE:
			symbol.kinds = _kinds(text, start, end, block)
		WeavlyLineScanner.Part.SPEAKER:
			if text.substr(end).strip_edges(true, false).begins_with(":"):
				symbol.kinds = SPEAKER_KINDS.duplicate()
	if symbol.kinds.is_empty():
		return null
	if block == WeavlyLineScanner.Block.META:
		var entry: RegExMatch = _meta_entry_regex.search(text)
		if entry != null and entry.get_string(1) in ["pool", "slot"] and start >= entry.get_end(1):
			symbol.role = Role.MEMBERSHIP
	return symbol


# The kind the name at start declares, or -1.
static func _declared_kind(text: String, block: WeavlyLineScanner.Block, start: int) -> int:
	if block == WeavlyLineScanner.Block.ENV:
		var declaration: RegExMatch = WeavlyProjectIndex.declaration_regex.search(text)
		if declaration != null and declaration.get_start(2) == start:
			return WeavlyProjectIndex.DECLARATION_KINDS[declaration.get_string(1)]
	elif block != WeavlyLineScanner.Block.META and WeavlyLineScanner.directive(text) == "@node":
		var after: int = text.find("@node") + "@node".length()
		var name: String = WeavlyLineScanner.node_name(text)
		if name != "" and text.find(name, after) == start:
			return WeavlyProjectIndex.Kind.NODE
	return -1


static func _kinds(
	text: String, start: int, end: int, block: WeavlyLineScanner.Block
) -> Array[WeavlyProjectIndex.Kind]:
	var before: String = text.substr(0, start)
	var after: String = text.substr(end).strip_edges(true, false)
	if before.ends_with("@"):
		return []
	if before.ends_with("."):
		return [WeavlyProjectIndex.Kind.META_KEY]
	if _var_argument_regex.search(before) != null:
		return [WeavlyProjectIndex.Kind.VARIABLE]
	if after.begins_with("."):
		return NODE_TARGET_KINDS.duplicate()
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
		return NODE_TARGET_KINDS.duplicate()
	if _draw_regex.search(before) != null:
		return POOL_TARGET_KINDS.duplicate()
	if _pool_option_regex.search(before) != null:
		if after.begins_with(":"):
			return []
		if (
			_pool_argument_regex.search(before) != null
			and (after.begins_with(",") or after.begins_with(")"))
		):
			return POOL_TARGET_KINDS.duplicate()
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
		"character":
			return WeavlyProjectIndex.Kind.CHARACTER
	return WeavlyProjectIndex.Kind.NODE


static func _is_word_char(text: String, index: int) -> bool:
	if index < 0 or index >= text.length():
		return false
	var c: String = text[index]
	return (
		c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")
	)
