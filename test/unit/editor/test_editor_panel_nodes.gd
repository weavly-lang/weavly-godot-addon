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
	for i: int in _panel._node_picker.item_count:
		items.append(_panel._node_picker.get_item_text(i))
	return items


# TextEdit emits caret_changed a frame late.
func _move_caret(line: int) -> void:
	_panel._code_edit.set_caret_line(line)
	await await_idle_frame()


func test_picker_lists_the_nodes_in_order() -> void:
	_open_with_text(_NODES_TEXT)
	assert_array(_picker_items()).contains_exactly(["start", "second_one"])
	assert_bool(_panel._node_picker.disabled).is_false()


func test_picker_is_disabled_without_nodes() -> void:
	_open_with_text("# nothing here\n")
	assert_int(_panel._node_picker.item_count).is_equal(0)
	assert_bool(_panel._node_picker.disabled).is_true()


func test_lines_map_to_their_node() -> void:
	_open_with_text(_NODES_TEXT)
	assert_array(Array(_panel._line_nodes)).is_equal([-1, 0, 0, 0, -1, 1, 1, 1, -1])


func test_selecting_a_node_moves_the_caret_to_it() -> void:
	_open_with_text(_NODES_TEXT)
	_panel._node_picker.select(1)
	_panel._on_node_selected(1)
	assert_int(_panel._code_edit.get_caret_line()).is_equal(5)
	assert_int(_panel._code_edit.get_caret_column()).is_equal(0)


func test_picker_follows_the_caret() -> void:
	_open_with_text(_NODES_TEXT)
	await _move_caret(6)
	assert_int(_panel._node_picker.selected).is_equal(1)
	await _move_caret(4)
	assert_int(_panel._node_picker.selected).is_equal(-1)
	await _move_caret(2)
	assert_int(_panel._node_picker.selected).is_equal(0)


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
		WeavlyEditorPanel._NODE_STRIP_WIDTH + WeavlyEditorPanel._NODE_STRIP_GAP
	)
