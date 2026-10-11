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
		_tint_lines()

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
	_code_edit.theme_changed.connect(_tint_lines)
	_code_edit.draw.connect(_draw_separators)


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
	_tint_lines()
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


func _tint_lines() -> void:
	var color: Color = Color(_code_edit.get_theme_color(&"font_color"), TINT_ALPHA)
	for line: int in _code_edit.get_line_count():
		_code_edit.set_line_background_color(line, Color.TRANSPARENT)
	if tint:
		for line: int in _node_lines:
			_code_edit.set_line_background_color(line, color)


# The @node lines that get a separator; there is none above the first line.
func separated_lines() -> PackedInt32Array:
	var lines: PackedInt32Array = []
	if separator:
		for line: int in _node_lines:
			if line > 0:
				lines.append(line)
	return lines


func _draw_separators() -> void:
	var color: Color = Color(_code_edit.get_theme_color(&"font_color"), SEPARATOR_ALPHA)
	var style: StyleBox = _code_edit.get_theme_stylebox(&"normal")
	var left: float = style.get_margin(SIDE_LEFT) + _code_edit.get_total_gutter_width()
	var right: float = _code_edit.size.x - style.get_margin(SIDE_RIGHT)
	var scroll_bar: VScrollBar = _code_edit.get_v_scroll_bar()
	if scroll_bar.visible:
		right = scroll_bar.position.x
	for line: int in separated_lines():
		var row: Rect2i = _code_edit.get_rect_at_line_column(line, 0)
		if row.position.y >= 0:
			_code_edit.draw_line(
				Vector2(left, row.position.y), Vector2(right, row.position.y), color
			)
