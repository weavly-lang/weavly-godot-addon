# gdlint:ignore = max-public-methods
extends GdUnitTestSuite

const _ENV = "@env\nvar energy: number = 3\npool city\n@endenv\n"
const _STORY = """@node hub
@jump market
@draw city
@if visited(harbor): @jump hub
$energy: Tired.
@jump nowhere
@endnode
"""
const _CITY = """@node market
@meta
pool: city
@endmeta
@endnode

@node harbor
@meta
pool: city
@endmeta
@endnode

@node city
@endnode
"""

var _panel: WeavlyEditorPanel
var _dir: String
var _story: String
var _city: String


func before_test() -> void:
	_dir = ProjectSettings.globalize_path(
		create_temp_dir("code_navigator_%d" % Time.get_ticks_usec())
	)
	ProjectSettings.set_setting(WeavlyEditorPanel.SETTING_PROJECT_DIR, _dir)
	_write_file("src/env.wvl", _ENV)
	_story = _write_file("src/story.wvl", _STORY)
	_city = _write_file("src/city.wvl", _CITY)
	_panel = auto_free(WeavlyEditorPanel.new())
	add_child(_panel)
	_panel.open_file(_story)


func after_test() -> void:
	ProjectSettings.set_setting(WeavlyEditorPanel.SETTING_PROJECT_DIR, null)


func _write_file(relative: String, text: String) -> String:
	var path: String = _dir.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path.simplify_path()


# The column of the first match of word on the line.
func _look_up(line: int, word: String) -> void:
	_panel._navigator.look_up(line, _panel._code_edit.get_line(line).find(word))


func _where() -> String:
	return "%s:%d" % [_panel.get_current_path().get_file(), _panel._code_edit.get_caret_line()]


func _listed() -> Array[String]:
	var items: Array[String] = []
	var navigator: WeavlyCodeNavigator = _panel._navigator
	for i: int in navigator.item_count:
		var text: String = navigator.get_item_text(i)
		items.append("-- " + text if navigator.is_item_separator(i) else text)
	return items


func _key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.alt_pressed = true
	event.pressed = true
	return event


func test_a_node_in_another_file_opens_at_its_line() -> void:
	_look_up(1, "market")
	assert_str(_where()).is_equal("city.wvl:0")


func test_a_node_in_the_same_file_moves_the_caret() -> void:
	_look_up(3, "hub")
	assert_str(_where()).is_equal("story.wvl:0")


func test_a_variable_goes_to_its_declaration() -> void:
	_look_up(4, "energy")
	assert_str(_where()).is_equal("env.wvl:1")


func test_an_unknown_name_stays_put() -> void:
	_panel._code_edit.set_caret_line(5)
	_look_up(5, "nowhere")
	assert_str(_where()).is_equal("story.wvl:5")
	assert_bool(_panel._navigator.visible).is_false()


func test_a_built_in_function_has_no_target() -> void:
	assert_array(_panel._navigator.sections_at(3, 5)).is_empty()


func test_a_pool_lists_its_nodes() -> void:
	_look_up(2, "city")
	assert_bool(_panel._navigator.visible).is_true()
	assert_array(_listed()).is_equal(
		["-- pool city", "market  src/city.wvl:1", "harbor  src/city.wvl:7"]
	)
	assert_str(_where()).is_equal("story.wvl:0")


func test_choosing_a_listed_node_goes_there() -> void:
	_look_up(2, "city")
	_panel._navigator.id_pressed.emit(1)
	assert_str(_where()).is_equal("city.wvl:6")


func test_a_bare_name_lists_every_kind_it_matches() -> void:
	_panel._code_edit.set_line(3, "@if visited(city): @jump hub")
	_look_up(3, "city")
	(
		assert_array(_listed())
		. is_equal(
			[
				"-- node city",
				"city  src/city.wvl:13",
				"-- pool city",
				"market  src/city.wvl:1",
				"harbor  src/city.wvl:7",
			]
		)
	)


func test_unsaved_text_of_the_open_file_is_used() -> void:
	assert_array(_panel._navigator.sections_at(1, 7)).is_not_empty()
	_panel._code_edit.insert_line_at(7, "@node fresh\n@endnode")
	_panel._code_edit.set_line(5, "@jump fresh")
	await await_idle_frame()
	_look_up(5, "fresh")
	assert_str(_where()).is_equal("story.wvl:7")


func test_back_and_forward_retrace_the_jumps() -> void:
	_panel._code_edit.set_caret_line(1)
	_look_up(1, "market")
	_panel._navigator.back()
	assert_str(_where()).is_equal("story.wvl:1")
	_panel._navigator.forward()
	assert_str(_where()).is_equal("city.wvl:0")


func test_a_new_jump_clears_forward() -> void:
	_look_up(1, "market")
	_panel._navigator.back()
	_look_up(3, "hub")
	_panel._navigator.forward()
	assert_str(_where()).is_equal("story.wvl:0")


func test_back_without_history_stays_put() -> void:
	_panel._code_edit.set_caret_line(2)
	_panel._navigator.back()
	assert_str(_where()).is_equal("story.wvl:2")


func test_alt_left_and_alt_right_go_back_and_forward() -> void:
	_panel._code_edit.set_caret_line(1)
	_look_up(1, "market")
	_panel._shortcut_input(_key_event(KEY_LEFT))
	assert_str(_where()).is_equal("story.wvl:1")
	_panel._shortcut_input(_key_event(KEY_RIGHT))
	assert_str(_where()).is_equal("city.wvl:0")


func test_ctrl_click_is_enabled() -> void:
	assert_bool(_panel._code_edit.symbol_lookup_on_click).is_true()


func _tooltip(line: int, word: String) -> String:
	return _panel._navigator.tooltip_at(line, _panel._code_edit.get_line(line).find(word))


func test_a_node_tooltip_shows_its_meta_block() -> void:
	assert_str(_tooltip(1, "market")).is_equal(
		"src/city.wvl:1\n@node market\n@meta\npool: city\n@endmeta"
	)


func test_a_variable_tooltip_shows_its_declaration() -> void:
	assert_str(_tooltip(4, "energy")).is_equal("src/env.wvl:2\nvar energy: number = 3")


func test_a_pool_tooltip_counts_its_nodes() -> void:
	assert_str(_tooltip(2, "city")).is_equal("src/env.wvl:3\npool city\n2 nodes")


func test_an_undeclared_slot_tooltip_still_counts_its_nodes() -> void:
	_write_file("src/dock.wvl", "@node dock\n@meta\nslot: crew\n@endmeta\n@endnode\n")
	_panel._code_edit.set_line(3, "@if visited(crew): @jump hub")
	assert_str(_tooltip(3, "crew")).is_equal("slot crew\n1 node")


func test_a_bare_name_tooltip_shows_every_match() -> void:
	_panel._code_edit.set_line(3, "@if visited(city): @jump hub")
	assert_str(_tooltip(3, "city")).is_equal(
		"src/city.wvl:13\n@node city\n\nsrc/env.wvl:3\npool city\n2 nodes"
	)


func test_an_unknown_name_has_no_tooltip() -> void:
	assert_str(_tooltip(5, "nowhere")).is_empty()


func test_tooltips_use_the_code_font() -> void:
	var label: Label = auto_free(_panel._code_edit._make_custom_tooltip("@node market"))
	assert_str(label.text).is_equal("@node market")
	assert_object(label.get_theme_font("font")).is_same(_panel._code_edit.get_theme_font("font"))


# The viewport asks get_tooltip with the mouse position once the mouse rests.
func _tooltip_at_position(line: int, column: int, offset: Vector2 = Vector2.ZERO) -> String:
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.size = Vector2(800, 600)
	await await_idle_frame()
	var rect: Rect2i = _panel._code_edit.get_rect_at_line_column(line, column)
	return _panel._code_edit.get_tooltip(Vector2(rect.get_center()) + offset)


func test_resting_the_mouse_on_a_name_shows_its_tooltip() -> void:
	assert_str(await _tooltip_at_position(1, 8)).is_equal(
		"src/city.wvl:1\n@node market\n@meta\npool: city\n@endmeta"
	)


func test_resting_the_mouse_past_the_end_of_a_line_shows_none() -> void:
	assert_str(await _tooltip_at_position(1, 8, Vector2(500, 0))).is_empty()
