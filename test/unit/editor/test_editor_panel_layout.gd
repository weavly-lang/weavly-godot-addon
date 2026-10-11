extends WeavlyTestSuite

var _panel: WeavlyEditorPanel
var _path: String


func before_test() -> void:
	_panel = _new_panel()
	var lines: PackedStringArray = []
	for i: int in 200:
		lines.append("Line %d of the story." % i)
	_path = create_temp_dir("editor_panel_layout").path_join("story.wvl")
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _new_panel() -> WeavlyEditorPanel:
	var panel: WeavlyEditorPanel = auto_free(WeavlyEditorPanel.new())
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(800, 400)
	return panel


func _saved_layout() -> ConfigFile:
	_panel.open_file(_path)
	await await_idle_frame()
	_panel._code_edit.set_caret_line(120)
	_panel._code_edit.set_caret_column(5)
	_panel._code_edit.scroll_vertical = 100
	var layout: ConfigFile = ConfigFile.new()
	_panel.save_layout(layout)
	return layout


func test_the_open_file_comes_back_at_its_caret_and_scroll() -> void:
	var layout: ConfigFile = await _saved_layout()
	var restored: WeavlyEditorPanel = _new_panel()
	restored.restore_layout(layout)
	await await_idle_frame()
	await await_idle_frame()
	assert_str(restored.get_current_path()).is_equal(ProjectSettings.globalize_path(_path))
	assert_int(restored._code_edit.get_caret_line()).is_equal(120)
	assert_int(restored._code_edit.get_caret_column()).is_equal(5)
	assert_float(restored._code_edit.scroll_vertical).is_equal(100.0)


func test_a_file_gone_since_opens_nothing() -> void:
	var layout: ConfigFile = await _saved_layout()
	DirAccess.remove_absolute(_path)
	var restored: WeavlyEditorPanel = _new_panel()
	restored.restore_layout(layout)
	assert_str(restored.get_current_path()).is_empty()


func test_without_an_open_file_nothing_is_kept() -> void:
	var layout: ConfigFile = await _saved_layout()
	var empty: WeavlyEditorPanel = _new_panel()
	empty.save_layout(layout)
	assert_bool(layout.has_section("Weavly")).is_false()
	empty.restore_layout(layout)
	assert_str(empty.get_current_path()).is_empty()


func test_opening_a_file_signals_it() -> void:
	var opened: Array[bool] = []
	_panel.file_opened.connect(func() -> void: opened.append(true))
	_panel.open_file(_path)
	assert_array(opened).has_size(1)
