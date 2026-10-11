extends WeavlyTestSuite


class _PanelWithSettings:
	extends WeavlyEditorPanel

	var settings: Dictionary = {}

	func _get_editor_setting(setting: String, default: Variant) -> Variant:
		return settings.get(setting, default)


var _panel: _PanelWithSettings


func before_test() -> void:
	_panel = auto_free(_PanelWithSettings.new())
	add_child(_panel)


func test_caret_defaults_to_the_script_editors_settings() -> void:
	var code_edit: WeavlyCodeEdit = _panel._code_edit
	assert_int(code_edit.caret_type).is_equal(TextEdit.CARET_TYPE_LINE)
	assert_bool(code_edit.caret_blink).is_true()
	assert_float(code_edit.caret_blink_interval).is_equal(0.5)
	assert_bool(code_edit.highlight_current_line).is_true()
	assert_bool(code_edit.highlight_all_occurrences).is_true()


func test_caret_follows_the_editor_settings() -> void:
	var caret: String = WeavlyEditorPanel.SETTINGS_CARET
	_panel.settings = {
		caret + "type": TextEdit.CARET_TYPE_BLOCK,
		caret + "caret_blink": false,
		caret + "caret_blink_interval": 0.8,
		caret + "highlight_current_line": false,
		caret + "highlight_all_occurrences": false,
	}
	_panel._apply_caret_settings()
	var code_edit: WeavlyCodeEdit = _panel._code_edit
	assert_int(code_edit.caret_type).is_equal(TextEdit.CARET_TYPE_BLOCK)
	assert_bool(code_edit.caret_blink).is_false()
	assert_float(code_edit.caret_blink_interval).is_equal_approx(0.8, 0.001)
	assert_bool(code_edit.highlight_current_line).is_false()
	assert_bool(code_edit.highlight_all_occurrences).is_false()
