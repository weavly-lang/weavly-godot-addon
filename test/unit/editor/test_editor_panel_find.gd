extends GdUnitTestSuite

# The find bar itself is tested in test_find_bar.gd; these cover the panel's wiring.

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
	_panel._find_bar._find_field.text = text
	_panel._find_bar._on_find_text_changed(text)


func test_find_shortcut_opens_the_bar() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	assert_bool(_panel._find_bar.visible).is_true()
	assert_bool(_panel._find_bar._replace_row.visible).is_false()


func test_replace_shortcut_opens_the_bar_with_the_replace_row() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	assert_bool(_panel._find_bar.visible).is_true()
	assert_bool(_panel._find_bar._replace_row.visible).is_true()


func test_f3_and_shift_f3_move_between_matches() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_F))
	_search_for("beta")
	_panel._shortcut_input(_key(KEY_F3))
	assert_that(_selection()).is_equal(Vector2i(0, 1))
	_panel._shortcut_input(_key(KEY_F3, true))
	assert_that(_selection()).is_equal(Vector2i(6, 0))


func test_f3_does_nothing_while_the_bar_is_closed() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._find_bar._find_field.text = "beta"
	_panel._shortcut_input(_key(KEY_F3))
	assert_bool(_panel._code_edit.has_selection()).is_false()


func test_replace_all_marks_the_file_dirty_and_reports_the_count() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_command_key(KEY_H))
	_search_for("beta")
	_panel._find_bar._replace_field.text = "delta"
	_panel._find_bar.replace_all()
	await await_idle_frame()
	assert_bool(_panel._dirty).is_true()
	assert_str(_panel._status_label.text).is_equal("Replaced 3")
