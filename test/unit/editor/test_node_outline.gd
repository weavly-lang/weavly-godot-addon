extends GdUnitTestSuite

const _NODES_TEXT = "# intro\n@node start\nHello.\n@endnode\n\n  @node second_one\nBye.\n@endnode\n"


class _PanelWithSettings:
	extends WeavlyEditorPanel

	var settings: Dictionary = {}

	func _get_editor_setting(setting: String, default: Variant) -> Variant:
		return settings.get(setting, default)


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


func _open_wrapped() -> CodeEdit:
	_open_with_text("@node start\n" + "word ".repeat(60) + "\nshort\n@endnode\n")
	_panel._line_wrap.button_pressed = true
	# The headless viewport is tiny, so the panel gets a usual size instead of filling it.
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.size = Vector2(400, 700)
	await await_idle_frame()
	return _panel._code_edit


func test_node_lines_are_tinted() -> void:
	_open_with_text(_NODES_TEXT)
	assert_array(Array(_panel._node_outline.tinted_lines())).is_equal([1, 5])


func test_the_tint_moves_with_its_node_while_typing() -> void:
	_open_with_text(_NODES_TEXT)
	_panel._code_edit.set_caret_line(0)
	_panel._code_edit.set_caret_column(0)
	_panel._code_edit.insert_text_at_caret("\n")
	await await_idle_frame()
	assert_array(Array(_panel._node_outline.tinted_lines())).is_equal([2, 6])


func test_turning_the_tint_off_tints_none() -> void:
	_open_with_text(_NODES_TEXT)
	_panel._node_outline.tint = false
	assert_array(Array(_panel._node_outline.tinted_lines())).is_empty()


func test_a_node_line_starts_a_bit_before_its_text_and_ends_at_the_scroll_bar() -> void:
	var edit: CodeEdit = await _open_wrapped()
	var style: StyleBox = edit.get_theme_stylebox(&"normal")
	var text_start: float = style.get_margin(SIDE_LEFT) + edit.get_total_gutter_width()
	var rect: Rect2 = _panel._node_outline.line_rect(0)
	assert_float(rect.position.x).is_less(text_start)
	assert_float(rect.position.x).is_greater(text_start - edit.get_total_gutter_width())
	var scroll_bar: VScrollBar = edit.get_v_scroll_bar()
	var right: float = (
		scroll_bar.position.x if scroll_bar.visible else edit.size.x - style.get_margin(SIDE_RIGHT)
	)
	assert_float(rect.end.x).is_equal(right)


func test_a_wrapped_node_line_covers_every_row() -> void:
	var edit: CodeEdit = await _open_wrapped()
	edit.set_line(0, "@node start " + "word ".repeat(60))
	await await_idle_frame()
	var rows: int = edit.get_line_wrap_count(0) + 1
	assert_int(rows).is_greater(1)
	assert_float(_panel._node_outline.line_rect(0).size.y).is_equal(
		float(edit.get_line_height() * rows)
	)


func test_every_node_but_one_on_the_first_line_gets_a_separator() -> void:
	_open_with_text(_NODES_TEXT)
	assert_array(Array(_panel._node_outline.separated_lines())).is_equal([1, 5])
	_open_with_text("@node start\n@endnode\n@node next\n@endnode\n")
	assert_array(Array(_panel._node_outline.separated_lines())).is_equal([2])


func test_turning_the_separator_off_draws_none() -> void:
	_open_with_text(_NODES_TEXT)
	_panel._node_outline.separator = false
	assert_array(Array(_panel._node_outline.separated_lines())).is_empty()


func test_the_gutter_has_no_node_strip() -> void:
	var plain: CodeEdit = auto_free(CodeEdit.new())
	assert_int(_panel._code_edit.get_gutter_count()).is_equal(plain.get_gutter_count())


func test_both_styles_are_on_by_default() -> void:
	assert_bool(_panel._node_outline.separator).is_true()
	assert_bool(_panel._node_outline.tint).is_true()


func test_the_styles_follow_the_editor_settings() -> void:
	var panel: _PanelWithSettings = auto_free(_PanelWithSettings.new())
	add_child(panel)
	panel.settings = {
		WeavlyEditorPanel.SETTING_NODE_SEPARATOR: false, WeavlyEditorPanel.SETTING_NODE_TINT: false
	}
	panel._apply_node_settings()
	assert_bool(panel._node_outline.separator).is_false()
	assert_bool(panel._node_outline.tint).is_false()
