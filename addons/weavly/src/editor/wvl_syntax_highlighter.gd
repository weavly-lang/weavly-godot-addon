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

var _number_regex: RegEx = RegEx.create_from_string("\\b\\d+(?:\\.\\d+)?\\b")
var _variable_regex: RegEx = RegEx.create_from_string("\\$[A-Za-z_][A-Za-z0-9_]*")
var _string_regex: RegEx = RegEx.create_from_string('"(?:[^"\\\\\\n]|\\\\.)*"')
var _directive_regex: RegEx = RegEx.create_from_string("@[A-Za-z_]+")
var _character_regex: RegEx = RegEx.create_from_string("^[ \\t]*>[^:\\n]*:")


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
	_paint(colors, text, _string_regex, STRING_COLOR)
	_paint(colors, text, _character_regex, CHARACTER_COLOR)
	_paint(colors, text, _directive_regex, DIRECTIVE_COLOR)
	_paint_comment(colors, text)

	var result: Dictionary = {}
	for i in length:
		if i == 0 or colors[i] != colors[i - 1]:
			result[i] = {"color": colors[i]}
	return result


func _paint(colors: PackedColorArray, text: String, regex: RegEx, color: Color) -> void:
	for regex_match in regex.search_all(text):
		for i in range(regex_match.get_start(), regex_match.get_end()):
			colors[i] = color


func _paint_numbers(colors: PackedColorArray, text: String) -> void:
	for regex_match in _number_regex.search_all(text):
		var start: int = regex_match.get_start()
		if start > 0 and text[start - 1] == "-" and _starts_negative_number(text, start - 1):
			start -= 1
		for i in range(start, regex_match.get_end()):
			colors[i] = NUMBER_COLOR


# A minus belongs to the number only where a value can start, not after an
# operand, where it is subtraction.
func _starts_negative_number(text: String, minus: int) -> bool:
	for i in range(minus - 1, -1, -1):
		var character: String = text[i]
		if character == " " or character == "\t":
			continue
		return character in "=(,[+-*/<>!"
	return true


func _paint_comment(colors: PackedColorArray, text: String) -> void:
	var start: int = _comment_start(text)
	if start < 0:
		return
	for i in range(start, text.length()):
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
