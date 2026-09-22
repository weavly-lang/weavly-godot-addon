extends GdUnitTestSuite

const _FIND_TEXT = "alpha beta\nbeta gamma\nBETA\n"

var _panel: WeavlyEditorPanel
var _dir: String


func before_test() -> void:
	_panel = auto_free(WeavlyEditorPanel.new())
	add_child(_panel)
	_dir = create_temp_dir("editor_panel")


func _write_file(file_name: String, text: String) -> String:
	var path: String = _dir.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


# Replaces the buffer the way typing does: assigning `text` never emits
# text_changed, and TextEdit emits it a frame late.
func _type(text: String) -> void:
	_panel._code_edit.select_all()
	_panel._code_edit.insert_text_at_caret(text)
	await await_idle_frame()


# =====================
# open_file
# =====================


func test_open_file_loads_content() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	_panel.open_file(path)
	assert_str(_panel._code_edit.text).is_equal("@node a\n@endnode\n")


func test_open_file_ignores_empty_path() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	_panel.open_file(path)
	_panel.open_file("")
	assert_str(_panel._code_edit.text).is_equal("@node a\n@endnode\n")


# =====================
# Unsaved edits (issue #44)
# =====================


func test_open_other_file_saves_unsaved_edits() -> void:
	var first: String = _write_file("first.wvl", "@node first\n@endnode\n")
	var second: String = _write_file("second.wvl", "@node second\n@endnode\n")
	_panel.open_file(first)
	await _type("@node edited\n@endnode\n")
	_panel.open_file(second)
	assert_str(FileAccess.get_file_as_string(first)).is_equal("@node edited\n@endnode\n")
	assert_str(_panel._code_edit.text).is_equal("@node second\n@endnode\n")


func test_reopening_the_same_file_saves_unsaved_edits() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	_panel.open_file(path)
	await _type("@node edited\n@endnode\n")
	_panel.open_file(path)
	assert_str(FileAccess.get_file_as_string(path)).is_equal("@node edited\n@endnode\n")
	assert_str(_panel._code_edit.text).is_equal("@node edited\n@endnode\n")


func test_open_file_without_a_current_file_discards_scratch_text() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	await _type("typed without a file")
	_panel.open_file(path)
	assert_str(_panel._code_edit.text).is_equal("@node a\n@endnode\n")


# =====================
# Save shortcut (issue #45)
# =====================


# is_command_or_control_pressed() reads meta on macOS and ctrl elsewhere, so the
# event carries the modifier of the platform the suite runs on.
func _key_event(keycode: Key, shift: bool = false, alt: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	if OS.has_feature("macos"):
		event.meta_pressed = true
	else:
		event.ctrl_pressed = true
	event.shift_pressed = shift
	event.alt_pressed = alt
	return event


func test_save_shortcut_saves_with_the_platform_modifier() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	_panel.open_file(path)
	await _type("@node edited\n@endnode\n")
	_panel._shortcut_input(_key_event(KEY_S))
	assert_str(FileAccess.get_file_as_string(path)).is_equal("@node edited\n@endnode\n")


func test_save_shortcut_ignores_shift_and_alt() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	_panel.open_file(path)
	await _type("@node edited\n@endnode\n")
	_panel._shortcut_input(_key_event(KEY_S, true, false))
	_panel._shortcut_input(_key_event(KEY_S, false, true))
	assert_str(FileAccess.get_file_as_string(path)).is_equal("@node a\n@endnode\n")


func test_save_shortcut_ignores_other_keys() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	_panel.open_file(path)
	await _type("@node edited\n@endnode\n")
	_panel._shortcut_input(_key_event(KEY_D))
	assert_str(FileAccess.get_file_as_string(path)).is_equal("@node a\n@endnode\n")


# =====================
# Line wrap (issue #95)
# =====================


func test_line_wrap_is_on_by_default() -> void:
	assert_bool(_panel._line_wrap.button_pressed).is_true()
	assert_int(_panel._code_edit.wrap_mode).is_equal(TextEdit.LINE_WRAPPING_BOUNDARY)


func test_line_wrap_toggle_sets_wrap_mode() -> void:
	_panel._line_wrap.button_pressed = false
	assert_int(_panel._code_edit.wrap_mode).is_equal(TextEdit.LINE_WRAPPING_NONE)
	_panel._line_wrap.button_pressed = true
	assert_int(_panel._code_edit.wrap_mode).is_equal(TextEdit.LINE_WRAPPING_BOUNDARY)


# =====================
# Find (issue #97)
# =====================


func _open_with_text(text: String) -> void:
	_panel.open_file(_write_file("find.wvl", text))


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


func test_find_shortcut_opens_the_bar() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_key_event(KEY_F))
	assert_bool(_panel._find_bar.visible).is_true()


func test_find_prefills_with_the_selection() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._code_edit.select(1, 5, 1, 10)
	_panel._shortcut_input(_key_event(KEY_F))
	assert_str(_panel._find_field.text).is_equal("gamma")


func test_find_ignores_a_multiline_selection() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._code_edit.select(0, 0, 1, 4)
	_panel._shortcut_input(_key_event(KEY_F))
	assert_str(_panel._find_field.text).is_empty()


func test_typing_selects_the_first_match_and_counts() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_key_event(KEY_F))
	_panel._find_field.text = "beta"
	_panel._on_find_text_changed("beta")
	assert_bool(_panel._code_edit.has_selection()).is_true()
	assert_that(_selection()).is_equal(Vector2i(6, 0))
	assert_str(_panel._find_count.text).is_equal("1 of 3")


func test_find_reports_no_matches() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_key_event(KEY_F))
	_panel._find_field.text = "delta"
	_panel._on_find_text_changed("delta")
	assert_bool(_panel._code_edit.has_selection()).is_false()
	assert_str(_panel._find_count.text).is_equal("No matches")


func test_enter_and_f3_go_to_the_next_match_and_wrap() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._shortcut_input(_key_event(KEY_F))
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
	_panel._shortcut_input(_key_event(KEY_F))
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
	_panel._shortcut_input(_key_event(KEY_F))
	_panel._find_field.text = "beta"
	_panel._on_find_text_changed("beta")
	_panel._on_find_field_input(_key(KEY_ESCAPE))
	assert_bool(_panel._find_bar.visible).is_false()


func test_f3_does_nothing_while_the_bar_is_closed() -> void:
	_open_with_text(_FIND_TEXT)
	_panel._find_field.text = "beta"
	_panel._shortcut_input(_key(KEY_F3))
	assert_bool(_panel._code_edit.has_selection()).is_false()
