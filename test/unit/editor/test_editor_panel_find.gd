extends GdUnitTestSuite

const _FIND_TEXT = "alpha beta\nbeta gamma\nBETA\n"

var _panel: WeavlyEditorPanel


func before_test() -> void:
	_panel = auto_free(WeavlyEditorPanel.new())
	add_child(_panel)


func _open_with_text(text: String) -> void:
	var path: String = create_temp_dir("editor_panel_find").path_join("find.wvl")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_panel.open_file(path)


# is_command_or_control_pressed() reads meta on macOS and ctrl elsewhere.
func _command_key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = _key(keycode)
	if OS.has_feature("macos"):
		event.meta_pressed = true
	else:
		event.ctrl_pressed = true
	return event


func _key(keycode: Key, shift: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.shift_pressed = shift
	return event


func _selection() -> Vector2i:
	return Vector2i(
		_panel._code_edit.get_selection_from_column(), _panel._code_edit.get_selection_from_line()
	)


func _search_for(text: String) -> void:
	_panel._find_field.text = text
	_panel._on_find_text_changed(text)


# =====================
# Find (issue #97)
# =====================


func test_find_shortcut_opens_the_bar() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	assert_bool(_panel._find_bar.visible).is_true()


func test_find_prefills_with_the_selection() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._code_edit.select(1, 5, 1, 10)
	_panel._shortcut_input(_command_key(KEY_F))
	assert_str(_panel._find_field.text).is_equal("gamma")


func test_find_ignores_a_multiline_selection() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._code_edit.select(0, 0, 1, 4)
	_panel._shortcut_input(_command_key(KEY_F))
	assert_str(_panel._find_field.text).is_empty()


func test_typing_selects_the_first_match_and_counts() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	_panel._find_field.text = "beta"
	_panel._on_find_text_changed("beta")
	assert_bool(_panel._code_edit.has_selection()).is_true()
	assert_that(_selection()).is_equal(Vector2i(6, 0))
	assert_str(_panel._find_count.text).is_equal("1 of 3")


func test_find_reports_no_matches() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	_panel._find_field.text = "delta"
	_panel._on_find_text_changed("delta")
	assert_bool(_panel._code_edit.has_selection()).is_false()
	assert_str(_panel._find_count.text).is_equal("No matches")


func test_enter_and_f3_go_to_the_next_match_and_wrap() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	_panel._find_field.text = "beta"
	_panel._on_find_text_changed("beta")
	_panel._on_find_field_input(_key(KEY_ENTER))
	assert_that(_selection()).is_equal(Vector2i(0, 1))
	_panel._shortcut_input(_key(KEY_F3))
	assert_that(_selection()).is_equal(Vector2i(0, 2))
	assert_str(_panel._find_count.text).is_equal("3 of 3")
	_panel._on_find_field_input(_key(KEY_ENTER))
	assert_that(_selection()).is_equal(Vector2i(6, 0))


func test_shift_goes_to_the_previous_match_and_wraps() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	_panel._find_field.text = "beta"
	_panel._on_find_text_changed("beta")
	_panel._on_find_field_input(_key(KEY_ENTER, true))
	assert_that(_selection()).is_equal(Vector2i(0, 2))
	_panel._shortcut_input(_key(KEY_F3, true))
	assert_that(_selection()).is_equal(Vector2i(0, 1))
	_panel._on_find_field_input(_key(KEY_ENTER, true))
	assert_that(_selection()).is_equal(Vector2i(6, 0))


func test_escape_closes_the_bar() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	_panel._find_field.text = "beta"
	_panel._on_find_text_changed("beta")
	_panel._on_find_field_input(_key(KEY_ESCAPE))
	assert_bool(_panel._find_bar.visible).is_false()


func test_f3_does_nothing_while_the_bar_is_closed() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._find_field.text = "beta"
	_panel._shortcut_input(_key(KEY_F3))
	assert_bool(_panel._code_edit.has_selection()).is_false()


# =====================
# Replace (issue #104)
# =====================


func test_replace_shortcut_shows_the_replace_row() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	assert_bool(_panel._find_bar.visible).is_true()
	assert_bool(_panel._replace_row.visible).is_true()
	_panel._shortcut_input(_command_key(KEY_F))
	assert_bool(_panel._replace_row.visible).is_false()


func test_replace_swaps_the_selected_match_and_moves_on() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	_search_for("beta")
	_panel._replace_field.text = "delta"
	_panel._on_replace_field_input(_key(KEY_ENTER))
	assert_str(_panel._code_edit.get_line(0)).is_equal("alpha delta")
	assert_that(_selection()).is_equal(Vector2i(0, 1))
	assert_str(_panel._find_count.text).is_equal("1 of 2")


func test_replace_without_a_selected_match_only_moves() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	_search_for("beta")
	_panel._code_edit.deselect()
	_panel._code_edit.set_caret_line(0)
	_panel._code_edit.set_caret_column(0)
	_panel._replace_field.text = "delta"
	_panel._replace()
	assert_str(_panel._code_edit.text).is_equal(_FIND_TEXT)
	assert_that(_selection()).is_equal(Vector2i(6, 0))


func test_replace_all_is_one_undo_step() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	_search_for("beta")
	_panel._replace_field.text = "delta"
	_panel._replace_all()
	assert_str(_panel._code_edit.text).is_equal("alpha delta\ndelta gamma\ndelta\n")
	assert_str(_panel._find_count.text).is_equal("No matches")
	_panel._code_edit.undo()
	assert_str(_panel._code_edit.text).is_equal(_FIND_TEXT)


func test_replace_all_marks_the_file_dirty() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	_search_for("beta")
	_panel._replace_field.text = "delta"
	_panel._replace_all()
	await await_idle_frame()
	assert_bool(_panel._dirty).is_true()


func test_match_case_limits_find_and_replace() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	_search_for("beta")
	_panel._match_case.button_pressed = true
	assert_str(_panel._find_count.text).is_equal("1 of 2")
	_panel._replace_field.text = "delta"
	_panel._replace_all()
	assert_str(_panel._code_edit.text).is_equal("alpha delta\ndelta gamma\nBETA\n")
