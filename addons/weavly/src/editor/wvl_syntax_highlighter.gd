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
var _string_regex: RegEx = RegEx.create_from_string('"[^"\\n]*"')
var _directive_regex: RegEx = RegEx.create_from_string("@[A-Za-z_]+")
var _character_regex: RegEx = RegEx.create_from_string("^[ \\t]*>[^:\\n]*:")
var _comment_regex: RegEx = RegEx.create_from_string("^[ \\t]*#.*")


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

	_paint(colors, text, _number_regex, NUMBER_COLOR)
	_paint(colors, text, _variable_regex, VARIABLE_COLOR)
	_paint(colors, text, _string_regex, STRING_COLOR)
	_paint(colors, text, _character_regex, CHARACTER_COLOR)
	_paint(colors, text, _directive_regex, DIRECTIVE_COLOR)
	_paint(colors, text, _comment_regex, COMMENT_COLOR)

	var result: Dictionary = {}
	for i in length:
		if i == 0 or colors[i] != colors[i - 1]:
			result[i] = {"color": colors[i]}
	return result


func _paint(colors: PackedColorArray, text: String, regex: RegEx, color: Color) -> void:
	for regex_match in regex.search_all(text):
		for i in range(regex_match.get_start(), regex_match.get_end()):
			colors[i] = color
