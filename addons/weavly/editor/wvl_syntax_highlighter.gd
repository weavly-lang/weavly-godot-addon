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
var _directive_regex: RegEx = RegEx.create_from_string("@[A-Za-z_]+")
var _character_regex: RegEx = RegEx.create_from_string("^[ \\t]*>[^:\\n]*:")
var _keyword_regex: RegEx = RegEx.create_from_string(
	"(?<![@$\\w])(?:and|or|not|true|false)(?!\\w)"
)
var _function_regex: RegEx = RegEx.create_from_string("(?<![@$\\w])[A-Za-z_]\\w*(?=\\()")
var _kind_regex: RegEx = RegEx.create_from_string(
	"^[ \\t]*((?:extern[ \\t]+)?var|pool|slot|meta|func|command)(?!\\w)"
)
var _type_regex: RegEx = RegEx.create_from_string(
	":[ \\t]*(number|string|flag|node|pool|slot)(?!\\w)"
)
var _flag_value_regex: RegEx = RegEx.create_from_string("=[ \\t]*(true|false)(?!\\w)")
var _meta_key_regex: RegEx = RegEx.create_from_string("^[ \\t]*([A-Za-z_]\\w*)[ \\t]*:")
var _option_call_regex: RegEx = RegEx.create_from_string("^[ \\t]*@option[ \\t]+(node|pool)\\(")
var _pool_parameter_regex: RegEx = RegEx.create_from_string(
	"(?<![\\w$])(limit|shuffle|locked)(?=[ \\t]*:)"
)
var _locked_value_regex: RegEx = RegEx.create_from_string(
	"locked[ \\t]*:[ \\t]*(show|extra|hide)(?!\\w)"
)

# Each line's WeavlyLineScanner.Block.
var _blocks: PackedInt32Array = []
var _blocks_stale: bool = true


func _update_cache() -> void:
	_blocks_stale = true
	var editor: TextEdit = get_text_edit()
	if editor != null and not editor.lines_edited_from.is_connected(_on_lines_edited):
		editor.lines_edited_from.connect(_on_lines_edited)


# A line's colors depend on the lines above it once it's inside an env or meta block.
func _on_lines_edited(_from_line: int, _to_line: int) -> void:
	_blocks_stale = true
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

	var block: WeavlyLineScanner.Block = _block_at(editor, line)
	_paint_numbers(colors, text)
	_paint(colors, text, _variable_regex, VARIABLE_COLOR)
	match block:
		WeavlyLineScanner.Block.ENV:
			_paint(colors, text, _kind_regex, KEYWORD_COLOR, 1)
			_paint(colors, text, _type_regex, KEYWORD_COLOR, 1)
			_paint(colors, text, _flag_value_regex, KEYWORD_COLOR, 1)
		WeavlyLineScanner.Block.META:
			_paint(colors, text, _meta_key_regex, KEYWORD_COLOR, 1)
			_paint_expression_words(colors, text)
		_:
			_paint_expression_words(colors, text)
			if _option_call_regex.search(text) != null:
				_paint(colors, text, _pool_parameter_regex, KEYWORD_COLOR, 1)
				_paint(colors, text, _locked_value_regex, KEYWORD_COLOR, 1)
	_paint(colors, text, _directive_regex, DIRECTIVE_COLOR)
	_paint_parts(colors, WeavlyLineScanner.parts(text, block))
	_paint(colors, text, _character_regex, CHARACTER_COLOR)

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


func _paint_expression_words(colors: PackedColorArray, text: String) -> void:
	_paint(colors, text, _keyword_regex, KEYWORD_COLOR)
	_paint(colors, text, _function_regex, FUNCTION_COLOR)


# Only code keeps the colors painted above; text, strings and comments get their own.
func _paint_parts(colors: PackedColorArray, parts: PackedByteArray) -> void:
	for i: int in parts.size():
		match parts[i]:
			WeavlyLineScanner.Part.TEXT:
				colors[i] = TEXT_COLOR
			WeavlyLineScanner.Part.STRING:
				colors[i] = STRING_COLOR
			WeavlyLineScanner.Part.COMMENT:
				colors[i] = COMMENT_COLOR


func _block_at(editor: TextEdit, line: int) -> WeavlyLineScanner.Block:
	if _blocks_stale:
		_blocks_stale = false
		var lines: PackedStringArray = []
		for i: int in editor.get_line_count():
			lines.append(editor.get_line(i))
		_blocks = WeavlyLineScanner.blocks(lines)
	return _blocks[line] if line < _blocks.size() else WeavlyLineScanner.Block.NONE


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
