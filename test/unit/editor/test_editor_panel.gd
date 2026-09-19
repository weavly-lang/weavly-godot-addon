extends GdUnitTestSuite

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
