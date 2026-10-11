@tool
class_name WeavlyNodeOutline
extends OptionButton

# Alphas of the theme's font color.
const SEPARATOR_ALPHA = 0.18
const TINT_ALPHA = 0.05

# A line above each @node.
var separator: bool = true:
	set(value):
		separator = value
		_code_edit.queue_redraw()
# A faint background on each @node line.
var tint: bool = true:
	set(value):
		tint = value
		_code_edit.queue_redraw()

var _code_edit: WeavlyCodeEdit
var _node_lines: PackedInt32Array = []
# Each line's index into _node_lines, -1 outside a node.
var _line_nodes: PackedInt32Array = []


func _init(code_edit: WeavlyCodeEdit) -> void:
	_code_edit = code_edit
	tooltip_text = "Go to node"
	item_selected.connect(_on_node_selected)
	_code_edit.text_changed.connect(refresh)
	_code_edit.caret_changed.connect(_sync_selection)
	_code_edit.draw.connect(_draw_node_lines)


func refresh() -> void:
	_node_lines.clear()
	clear()
	var lines: PackedStringArray = _code_edit.get_lines()
	var blocks: PackedInt32Array = _code_edit.get_blocks()
	_line_nodes.resize(lines.size())
	var node: int = -1
	for line: int in lines.size():
		var name: String = WeavlyLineScanner.node_name(lines[line])
		if name != "" and blocks[line] != WeavlyLineScanner.Block.ENV:
			node = _node_lines.size()
			_node_lines.append(line)
			add_item(name)
		elif blocks[line] == WeavlyLineScanner.Block.NONE:
			node = -1
		_line_nodes[line] = node
	disabled = _node_lines.is_empty()
	_sync_selection()
	_code_edit.queue_redraw()


func _sync_selection() -> void:
	var line: int = _code_edit.get_caret_line()
	select(_line_nodes[line] if line < _line_nodes.size() else -1)


func _on_node_selected(index: int) -> void:
	_code_edit.deselect()
	_code_edit.set_caret_line(_node_lines[index])
	_code_edit.set_caret_column(0)
	_code_edit.center_viewport_to_caret()
	_code_edit.grab_focus()


func tinted_lines() -> PackedInt32Array:
	return _node_lines if tint else PackedInt32Array()


# The @node lines that get a separator; there is none above the first line.
func separated_lines() -> PackedInt32Array:
	var lines: PackedInt32Array = []
	if separator:
		for line: int in _node_lines:
			if line > 0:
				lines.append(line)
	return lines


# The rows of a visible line, from half a character before the text to the scroll bar.
# CodeEdit doesn't clip, so the rows are cut to the text area.
func line_rect(line: int) -> Rect2:
	var row: Rect2i = _code_edit.get_rect_at_line_column(line, 0)
	if row.position.y < 0:
		return Rect2()
	var style: StyleBox = _code_edit.get_theme_stylebox(&"normal")
	var font: Font = _code_edit.get_theme_font(&"font")
	var font_size: int = _code_edit.get_theme_font_size(&"font_size")
	var left: float = (
		style.get_margin(SIDE_LEFT)
		+ _code_edit.get_total_gutter_width()
		- font.get_char_size(" ".unicode_at(0), font_size).x / 2.0
	)
	var right: float = _code_edit.size.x - style.get_margin(SIDE_RIGHT)
	var scroll_bar: VScrollBar = _code_edit.get_v_scroll_bar()
	if scroll_bar.visible:
		right = scroll_bar.position.x
	var rows: int = _code_edit.get_line_wrap_count(line) + 1
	var top: float = style.get_margin(SIDE_TOP)
	var text_area: Rect2 = Rect2(
		0.0, top, _code_edit.size.x, _code_edit.size.y - top - style.get_margin(SIDE_BOTTOM)
	)
	return (
		Rect2(left, row.position.y, right - left, _code_edit.get_line_height() * rows)
		. intersection(text_area)
	)


func _draw_node_lines() -> void:
	var first: int = _code_edit.get_first_visible_line()
	var last: int = _code_edit.get_last_full_visible_line() + 1
	var font_color: Color = _code_edit.get_theme_color(&"font_color")
	for line: int in tinted_lines():
		if line >= first and line <= last:
			var rect: Rect2 = line_rect(line)
			if rect.has_area():
				_code_edit.draw_rect(rect, Color(font_color, TINT_ALPHA))
	for line: int in separated_lines():
		if line >= first and line <= last:
			var rect: Rect2 = line_rect(line)
			if rect.has_area():
				_code_edit.draw_line(
					rect.position,
					Vector2(rect.end.x, rect.position.y),
					Color(font_color, SEPARATOR_ALPHA)
				)
