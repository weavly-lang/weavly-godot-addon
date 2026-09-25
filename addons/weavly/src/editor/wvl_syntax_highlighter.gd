@tool
class_name WvlSyntaxHighlighter
extends SyntaxHighlighter

const TEXT_COLOR = Color(0.86, 0.86, 0.86)
const DIRECTIVE_COLOR = Color(0.90, 0.46, 0.70)
const VARIABLE_COLOR = Color(0.90, 0.60, 0.32)
const STRING_COLOR = Color(0.80, 0.84, 0.46)
const NUMBER_COLOR = Color(0.40, 0.70, 0.92)
const CHARACTER_COLOR = Color(0.46, 0.80, 0.72)
const COMMENT_COLOR = Color(0.50, 0.50, 0.50)
const KEYWORD_COLOR = Color(0.66, 0.60, 0.98)
const FUNCTION_COLOR = Color(0.96, 0.86, 0.50)

var _number_regex: RegEx = RegEx.create_from_string("\\b\\d+(?:\\.\\d+)?\\b")
var _variable_regex: RegEx = RegEx.create_from_string("\\$[A-Za-z_][A-Za-z0-9_]*")
var _string_regex: RegEx = RegEx.create_from_string('"(?:[^"\\\\\\n]|\\\\.)*"')
var _directive_regex: RegEx = RegEx.create_from_string("@[A-Za-z_]+")
var _character_regex: RegEx = RegEx.create_from_string("^[ \\t]*>[^:\\n]*:")
var _keyword_regex: RegEx = RegEx.create_from_string(
	"(?<![@$\\w])(?:and|or|not|true|false)(?!\\w)"
)
var _function_regex: RegEx = RegEx.create_from_string("(?<![@$\\w])[A-Za-z_]\\w*(?=\\()")
var _extern_regex: RegEx = RegEx.create_from_string("^[ \\t]*(extern)(?!\\w)")
var _type_regex: RegEx = RegEx.create_from_string(":[ \\t]*(number|string|flag|pool|slot)(?!\\w)")
var _flag_value_regex: RegEx = RegEx.create_from_string("=[ \\t]*(true|false)(?!\\w)")
var _block_directive_regex: RegEx = RegEx.create_from_string("^[ \\t]*(@[A-Za-z_]+)")
var _meta_key_regex: RegEx = RegEx.create_from_string(
	"^[ \\t]*(pool|slot|when|priority|weight|once)[ \\t]*:"
)
var _text_directive_regex: RegEx = RegEx.create_from_string("^[ \\t]*@(option|hint|continue)\\b")
var _interpolation_regex: RegEx = RegEx.create_from_string("(?<!\\\\)\\{[^{}\\n]*\\}")

# Line -> "@env" or "@meta" for the lines inside such a block.
var _block_lines: Dictionary[int, String] = {}
var _block_lines_stale: bool = true


func _update_cache() -> void:
	_block_lines_stale = true
	var editor: TextEdit = get_text_edit()
	if editor != null and not editor.lines_edited_from.is_connected(_on_lines_edited):
		editor.lines_edited_from.connect(_on_lines_edited)


# A line's colors depend on the lines above it once it's inside an env or meta block.
func _on_lines_edited(_from_line: int, _to_line: int) -> void:
	_block_lines_stale = true
	clear_highlighting_cache()


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var editor: TextEdit = get_text_edit()
	if editor == null:
		return {}

	var text: String = editor.get_line(line)
	var length: int = text.length()
	if length == 0:
		return {}

	var colors: PackedColorArray = PackedColorArray()
	colors.resize(length)
	colors.fill(TEXT_COLOR)

	_paint_numbers(colors, text)
	_paint(colors, text, _variable_regex, VARIABLE_COLOR)
	# Where text that can hold {} interpolations starts; the line's length when it has none.
	var text_start: int = 0
	match _block_at(editor, line):
		"@env":
			_paint(colors, text, _extern_regex, KEYWORD_COLOR, 1)
			_paint(colors, text, _type_regex, KEYWORD_COLOR, 1)
			_paint(colors, text, _flag_value_regex, KEYWORD_COLOR, 1)
			text_start = length
		"@meta":
			_paint(colors, text, _meta_key_regex, KEYWORD_COLOR, 1)
			_paint_expression_words(colors, text, 0, length)
			text_start = length
		_:
			if text.strip_edges(true, false).begins_with("@"):
				var end: int = _expression_end(text)
				_paint_expression_words(colors, text, 0, end)
				text_start = 0 if _text_directive_regex.search(text) != null else end
	_paint(colors, text, _string_regex, STRING_COLOR)
	_paint(colors, text, _character_regex, CHARACTER_COLOR)
	_paint(colors, text, _directive_regex, DIRECTIVE_COLOR)
	_paint_interpolations(colors, text, text_start)
	_paint_comment(colors, text)

	var result: Dictionary = {}
	for i: int in length:
		if i == 0 or colors[i] != colors[i - 1]:
			result[i] = {"color": colors[i]}
	return result


func _paint(
	colors: PackedColorArray,
	text: String,
	regex: RegEx,
	color: Color,
	group: int = 0,
	start: int = 0,
	end: int = -1,
) -> void:
	for regex_match: RegExMatch in regex.search_all(text, start, end):
		for i: int in range(regex_match.get_start(group), regex_match.get_end(group)):
			colors[i] = color


func _paint_expression_words(colors: PackedColorArray, text: String, start: int, end: int) -> void:
	_paint(colors, text, _keyword_regex, KEYWORD_COLOR, 0, start, end)
	_paint(colors, text, _function_regex, FUNCTION_COLOR, 0, start, end)


# An interpolation is colored as an expression, even inside an option's quoted text.
func _paint_interpolations(colors: PackedColorArray, text: String, start: int) -> void:
	for found: RegExMatch in _interpolation_regex.search_all(text, start):
		var from: int = found.get_start()
		var to: int = found.get_end()
		for i: int in range(from, to):
			colors[i] = TEXT_COLOR
		_paint(colors, text, _number_regex, NUMBER_COLOR, 0, from, to)
		_paint(colors, text, _variable_regex, VARIABLE_COLOR, 0, from, to)
		_paint_expression_words(colors, text, from, to)
		_paint(colors, text, _string_regex, STRING_COLOR, 0, from, to)


func _block_at(editor: TextEdit, line: int) -> String:
	if _block_lines_stale:
		_find_block_lines(editor)
	return _block_lines.get(line, "")


func _find_block_lines(editor: TextEdit) -> void:
	_block_lines.clear()
	_block_lines_stale = false
	var block: String = ""
	for i: int in editor.get_line_count():
		var found: RegExMatch = _block_directive_regex.search(editor.get_line(i))
		if found != null:
			match found.get_string(1):
				"@env", "@meta":
					block = found.get_string(1)
					continue
				"@endenv", "@endmeta", "@node", "@endnode":
					block = ""
		if block != "":
			_block_lines[i] = block


# An inline statement after ':' is line text unless it's another directive.
func _expression_end(text: String) -> int:
	var in_string: bool = false
	var i: int = 0
	while i < text.length():
		var character: String = text[i]
		if in_string:
			if character == "\\":
				i += 1
			elif character == '"':
				in_string = false
		elif character == '"':
			in_string = true
		elif character == ":" and not text.substr(i + 1).strip_edges(true, false).begins_with("@"):
			return i
		i += 1
	return text.length()


func _paint_numbers(colors: PackedColorArray, text: String) -> void:
	for regex_match: RegExMatch in _number_regex.search_all(text):
		var start: int = regex_match.get_start()
		if start > 0 and text[start - 1] == "-" and _starts_negative_number(text, start - 1):
			start -= 1
		for i: int in range(start, regex_match.get_end()):
			colors[i] = NUMBER_COLOR


# A minus belongs to the number only where a value can start, not after an
# operand, where it is subtraction.
func _starts_negative_number(text: String, minus: int) -> bool:
	for i: int in range(minus - 1, -1, -1):
		var character: String = text[i]
		if character == " " or character == "\t":
			continue
		return character in "=(,[+-*/<>!"
	return true


func _paint_comment(colors: PackedColorArray, text: String) -> void:
	var start: int = _comment_start(text)
	if start < 0:
		return
	for i: int in range(start, text.length()):
		colors[i] = COMMENT_COLOR


# Comments run to the end of the line. On narration and character lines a '#' is
# part of the text, so only whole-line comments and comments after a directive
# count. Inside a string it is text as well.
func _comment_start(text: String) -> int:
	var stripped: String = text.strip_edges(true, false)
	if stripped.begins_with("#"):
		return text.length() - stripped.length()
	if not stripped.begins_with("@"):
		return -1

	var in_string: bool = false
	var i: int = 0
	while i < text.length():
		var character: String = text[i]
		if in_string:
			if character == "\\":
				i += 1
			elif character == '"':
				in_string = false
		elif character == '"':
			in_string = true
		elif character == "#":
			return i
		i += 1
	return -1
