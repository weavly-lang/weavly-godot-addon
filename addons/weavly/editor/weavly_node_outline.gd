@tool
class_name WeavlyNodeOutline
extends OptionButton

const STRIP_COLORS: Array[Color] = [Color(0.35, 0.56, 0.88), Color(0.88, 0.67, 0.35)]
const STRIP_WIDTH = 4
const STRIP_GAP = 6

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

	var gutter: int = _code_edit.get_gutter_count()
	_code_edit.add_gutter(gutter)
	_code_edit.set_gutter_type(gutter, TextEdit.GUTTER_TYPE_CUSTOM)
	_code_edit.set_gutter_width(gutter, STRIP_WIDTH + STRIP_GAP)
	_code_edit.set_gutter_custom_draw(gutter, _draw_gutter)


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


func _draw_gutter(line: int, _gutter: int, area: Rect2) -> void:
	if line >= _line_nodes.size() or _line_nodes[line] == -1:
		return
	var strip: Rect2 = _strip_rect(line, area)
	if strip.has_area():
		var color: Color = STRIP_COLORS[_line_nodes[line] % STRIP_COLORS.size()]
		_code_edit.draw_rect(strip, color)


# The gutter is drawn once per line on its first row, so the strip spans the wrapped rows too.
# CodeEdit doesn't clip, so the strip is cut to the text area.
func _strip_rect(line: int, area: Rect2) -> Rect2:
	var rows: int = _code_edit.get_line_wrap_count(line) + 1
	var strip: Rect2 = Rect2(area.position, Vector2(STRIP_WIDTH, area.size.y * rows))
	var style: StyleBox = _code_edit.get_theme_stylebox(&"normal")
	var top: float = style.get_margin(SIDE_TOP)
	var text_area: Rect2 = Rect2(
		0.0, top, _code_edit.size.x, _code_edit.size.y - top - style.get_margin(SIDE_BOTTOM)
	)
	return strip.intersection(text_area)
