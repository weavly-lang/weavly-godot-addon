@tool
class_name WeavlyCodeEdit
extends CodeEdit

# Takes a line and column and returns the tooltip there; empty shows none.
var tooltip_source: Callable

var _lines: PackedStringArray = []
# Each line's WeavlyLineScanner.Block.
var _blocks: PackedInt32Array = []
var _scanned: bool = false


func _init() -> void:
	lines_edited_from.connect(func(_from_line: int, _to_line: int) -> void: _scanned = false)


# Collected once per text change, shared by the outline and the highlighter.
func get_lines() -> PackedStringArray:
	_scan()
	return _lines


func get_blocks() -> PackedInt32Array:
	_scan()
	return _blocks


func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	_lines.resize(get_line_count())
	for line: int in _lines.size():
		_lines[line] = get_line(line)
	_blocks = WeavlyLineScanner.blocks(_lines)


func _get_tooltip(at_position: Vector2) -> String:
	var at: Vector2i = get_line_column_at_pos(Vector2i(at_position), false)
	if at.y < 0 or not tooltip_source.is_valid():
		return ""
	var line_end: Rect2i = get_rect_at_line_column(at.y, get_line(at.y).length())
	if at_position.y >= line_end.position.y and at_position.x > line_end.end.x:
		return ""
	return tooltip_source.call(at.y, at.x)


# Tooltips show source, so they use the code font.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	var label: Label = Label.new()
	label.text = for_text
	label.add_theme_font_override("font", get_theme_font("font"))
	label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	return label
