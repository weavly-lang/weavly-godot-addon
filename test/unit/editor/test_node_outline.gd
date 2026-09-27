extends GdUnitTestSuite

const _NODES_TEXT = "# intro\n@node start\nHello.\n@endnode\n\n  @node second_one\nBye.\n@endnode\n"

var _panel: WeavlyEditorPanel


func before_test() -> void:
	_panel = auto_free(WeavlyEditorPanel.new())
	add_child(_panel)


func _open_with_text(text: String) -> void:
	var path: String = create_temp_dir("editor_panel_nodes").path_join("nodes.wvl")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_panel.open_file(path)


func _picker_items() -> PackedStringArray:
	var items: PackedStringArray = []
	for i: int in _panel._node_outline.item_count:
		items.append(_panel._node_outline.get_item_text(i))
	return items


# TextEdit emits caret_changed a frame late.
func _move_caret(line: int) -> void:
	_panel._code_edit.set_caret_line(line)
	await await_idle_frame()


func test_picker_lists_the_nodes_in_order() -> void:
	_open_with_text(_NODES_TEXT)
	assert_array(_picker_items()).contains_exactly(["start", "second_one"])
	assert_bool(_panel._node_outline.disabled).is_false()


func test_picker_is_disabled_without_nodes() -> void:
	_open_with_text("# nothing here\n")
	assert_int(_panel._node_outline.item_count).is_equal(0)
	assert_bool(_panel._node_outline.disabled).is_true()


func test_lines_map_to_their_node() -> void:
	_open_with_text(_NODES_TEXT)
	assert_array(Array(_panel._node_outline._line_nodes)).is_equal([-1, 0, 0, 0, -1, 1, 1, 1, -1])


func test_selecting_a_node_moves_the_caret_to_it() -> void:
	_open_with_text(_NODES_TEXT)
	_panel._node_outline.select(1)
	_panel._node_outline._on_node_selected(1)
	assert_int(_panel._code_edit.get_caret_line()).is_equal(5)
	assert_int(_panel._code_edit.get_caret_column()).is_equal(0)


func test_picker_follows_the_caret() -> void:
	_open_with_text(_NODES_TEXT)
	await _move_caret(6)
	assert_int(_panel._node_outline.selected).is_equal(1)
	await _move_caret(4)
	assert_int(_panel._node_outline.selected).is_equal(-1)
	await _move_caret(2)
	assert_int(_panel._node_outline.selected).is_equal(0)


func test_nodes_update_while_typing() -> void:
	_open_with_text(_NODES_TEXT)
	_panel._code_edit.set_caret_line(_panel._code_edit.get_line_count() - 1)
	_panel._code_edit.insert_text_at_caret("@node third\n@endnode\n")
	await await_idle_frame()
	assert_array(_picker_items()).contains_exactly(["start", "second_one", "third"])


func test_node_gutter_is_a_custom_strip() -> void:
	var gutter: int = _panel._code_edit.get_gutter_count() - 1
	assert_int(_panel._code_edit.get_gutter_type(gutter)).is_equal(TextEdit.GUTTER_TYPE_CUSTOM)
	assert_int(_panel._code_edit.get_gutter_width(gutter)).is_equal(
		WeavlyNodeOutline.STRIP_WIDTH + WeavlyNodeOutline.STRIP_GAP
	)


func _open_wrapped() -> CodeEdit:
	_open_with_text("@node start\n" + "word ".repeat(60) + "\nshort\n@endnode\n")
	var edit: CodeEdit = _panel._code_edit
	_panel._line_wrap.button_pressed = true
	# The headless viewport is tiny, so the panel gets a usual size instead of filling it.
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.size = Vector2(400, 700)
	await await_idle_frame()
	return edit


func _text_area(edit: CodeEdit) -> Rect2:
	var style: StyleBox = edit.get_theme_stylebox(&"normal")
	var top: float = style.get_margin(SIDE_TOP)
	return Rect2(0.0, top, edit.size.x, edit.size.y - top - style.get_margin(SIDE_BOTTOM))


func test_node_strip_spans_every_row_of_a_wrapped_line() -> void:
	var edit: CodeEdit = await _open_wrapped()
	var rows: int = edit.get_line_wrap_count(1) + 1
	assert_int(rows).is_greater(1)
	var height: float = edit.get_line_height()
	var strip: Rect2 = _panel._node_outline._strip_rect(1, Rect2(4, 40, 10, height))
	assert_that(strip).is_equal(Rect2(4, 40, WeavlyNodeOutline.STRIP_WIDTH, height * rows))


func test_node_strip_covers_one_row_without_wrap() -> void:
	var edit: CodeEdit = await _open_wrapped()
	_panel._line_wrap.button_pressed = false
	await await_idle_frame()
	var height: float = edit.get_line_height()
	var strip: Rect2 = _panel._node_outline._strip_rect(1, Rect2(4, 40, 10, height))
	assert_that(strip).is_equal(Rect2(4, 40, WeavlyNodeOutline.STRIP_WIDTH, height))


func test_node_strip_stays_inside_the_text_area() -> void:
	var edit: CodeEdit = await _open_wrapped()
	var height: float = edit.get_line_height()
	var text_area: Rect2 = _text_area(edit)
	var above: Rect2 = _panel._node_outline._strip_rect(1, Rect2(4, -height * 2, 10, height))
	assert_float(above.position.y).is_equal(text_area.position.y)
	var below: Rect2 = _panel._node_outline._strip_rect(
		1, Rect2(4, edit.size.y - height, 10, height)
	)
	assert_float(below.end.y).is_equal(text_area.end.y)
