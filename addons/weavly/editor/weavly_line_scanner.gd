@tool
class_name WeavlyLineScanner
extends RefCounted

# A block's opening line is still outside it, its closing line inside.
enum Block { NONE, ENV, BODY, META }

# {} interpolations in text and strings are code; their braces are text.
enum Part { TEXT, CODE, STRING, COMMENT }

static var _directive_regex: RegEx = RegEx.create_from_string("^[ \\t]*(@[A-Za-z_]\\w*)")
static var _node_regex: RegEx = RegEx.create_from_string("^[ \\t]*@node[ \\t]+([A-Za-z_]\\w*)")


# Each line's block.
static func blocks(lines: PackedStringArray) -> PackedInt32Array:
	var result: PackedInt32Array = []
	result.resize(lines.size())
	var block: Block = Block.NONE
	for line: int in lines.size():
		result[line] = block
		block = next_block(block, lines[line])
	return result


static func block_at(lines: PackedStringArray, line: int) -> Block:
	var block: Block = Block.NONE
	for i: int in line:
		block = next_block(block, lines[i])
	return block


# The block the lines after text are in. A missing @endnode doesn't hide a later @node or @env.
static func next_block(block: Block, text: String) -> Block:
	var found: String = directive(text)
	if block == Block.ENV:
		return Block.NONE if found == "@endenv" else block
	if block == Block.META:
		return Block.BODY if found == "@endmeta" else block
	match found:
		"@env":
			return Block.ENV
		"@node":
			return Block.BODY
		"@endnode":
			return Block.NONE
		"@meta":
			return Block.META if block == Block.BODY else block
	return block


# The directive the line starts with, or empty.
static func directive(text: String) -> String:
	var found: RegExMatch = _directive_regex.search(text)
	return "" if found == null else found.get_string(1)


# The name an @node line declares, or empty.
static func node_name(text: String) -> String:
	var found: RegExMatch = _node_regex.search(text)
	return "" if found == null else found.get_string(1)


# Each character's Part. Env and meta lines are code; other lines are text unless they start
# with a directive or a variable.
static func parts(text: String, block: Block) -> PackedByteArray:
	var result: PackedByteArray = []
	result.resize(text.length())
	if block == Block.ENV or block == Block.META:
		_scan_code(text, 0, result, false)
	else:
		_scan_line(text, 0, result)
	return result


# A body line, or the part after an inline action's colon.
static func _scan_line(text: String, from: int, result: PackedByteArray) -> void:
	var i: int = from
	while i < text.length() and text[i] in " \t":
		i += 1
	if i >= text.length():
		return
	if text[i] == "#":
		_mark(result, i, text.length(), Part.COMMENT)
	elif text[i] == "@":
		var colon: int = _scan_code(text, i, result, true)
		if colon >= 0:
			_scan_line(text, colon + 1, result)
	elif text[i] == "$":
		var colon: int = _scan_code(text, i, result, true)
		if colon >= 0:
			_scan_text(text, colon + 1, result)
	elif text[i] == ">":
		var colon: int = text.find(":", i)
		if colon >= 0:
			_scan_text(text, colon + 1, result)
	else:
		_scan_text(text, i, result)


# Returns the first colon outside brackets when stopping there, else -1.
static func _scan_code(
	text: String, from: int, result: PackedByteArray, stop_at_colon: bool
) -> int:
	var depth: int = 0
	var i: int = from
	while i < text.length():
		var c: String = text[i]
		if c == '"':
			i = _scan_string(text, i, result)
			continue
		if c == "#":
			_mark(result, i, text.length(), Part.COMMENT)
			return -1
		if c == ":" and depth == 0 and stop_at_colon:
			return i
		if c in "([":
			depth += 1
		elif c in ")]":
			depth = maxi(depth - 1, 0)
		result[i] = Part.CODE
		i += 1
	return -1


# Returns the index after the closing quote.
static func _scan_string(text: String, from: int, result: PackedByteArray) -> int:
	result[from] = Part.STRING
	var i: int = from + 1
	while i < text.length() and text[i] != '"':
		if text[i] == "\\":
			_mark(result, i, i + 2, Part.STRING)
			i += 2
		elif text[i] == "{":
			i = _scan_interpolation(text, i, result)
		else:
			result[i] = Part.STRING
			i += 1
	_mark(result, i, i + 1, Part.STRING)
	return i + 1


static func _scan_text(text: String, from: int, result: PackedByteArray) -> void:
	var i: int = from
	while i < text.length():
		if text[i] == "\\":
			i += 2
		elif text[i] == "{":
			i = _scan_interpolation(text, i, result)
		else:
			i += 1


# Returns the index after the closing brace.
static func _scan_interpolation(text: String, from: int, result: PackedByteArray) -> int:
	var i: int = from + 1
	var quoted: bool = false
	while i < text.length() and (quoted or text[i] != "}"):
		if text[i] == '"':
			quoted = not quoted
			result[i] = Part.STRING
		else:
			result[i] = Part.STRING if quoted else Part.CODE
		i += 1
	return i + 1


# Marks [from, to) as part, clipped to the line.
static func _mark(result: PackedByteArray, from: int, to: int, part: Part) -> void:
	for i: int in range(from, mini(to, result.size())):
		result[i] = part
