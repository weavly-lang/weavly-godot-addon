# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# The debug overlay against the compiler-built fixture in debug/src/debug.wvl.

const FIXTURE = "res://test/fixtures/ui/debug"
const SCENE = preload("res://addons/weavly/ui/debug/weavly_debug_ui.tscn")
const TOGGLE = &"weavly_test_toggle_debug"

var _engine: WeavlyDefaultEngine
var _ui: WeavlyDebugUI


func before_test() -> void:
	_engine = WeavlyDefaultEngine.new()
	_engine.dialogue_path = FIXTURE + "/build"
	_engine.video_path = FIXTURE + "/build"
	_engine.image_path = FIXTURE + "/build"
	_engine.character_path = FIXTURE + "/build"
	_engine.variable_path = FIXTURE + "/build"
	add_child(auto_free(_engine))
	_ui = auto_free(SCENE.instantiate())
	_ui.engine = _engine
	_ui.toggle_action = TOGGLE
	add_child(_ui)
	_ui.visible = true


func after_test() -> void:
	if InputMap.has_action(TOGGLE):
		InputMap.erase_action(TOGGLE)
	await get_tree().process_frame


func _status() -> String:
	return (_ui.get_node("%Status") as Label).text


func _show_tab(tab: int) -> void:
	(_ui.get_node("%Tabs") as TabContainer).current_tab = tab


# The grid's cells in rows, each cell as text: labels by text, line edits by text, checks as bools.
func _rows(grid_name: String, columns: int) -> Array[Array]:
	var rows: Array[Array] = []
	var row: Array = []
	for cell: Node in _ui.get_node(grid_name).get_children():
		if not (cell as Control).visible:
			continue
		if cell is CheckBox:
			row.append(cell.button_pressed)
		elif cell is Label or cell is LineEdit:
			row.append(cell.text)
		else:
			row.append((cell as Button).text)
		if row.size() == columns:
			rows.append(row)
			row = []
	return rows


func _variable_editor(id: String) -> Control:
	var cells: Array[Node] = _ui.get_node("%VariableGrid").get_children()
	for i: int in range(0, cells.size(), 3):
		if (cells[i] as Label).text == id:
			return cells[i + 2]
	return null


func _node_cells(id: String) -> Array[Node]:
	var cells: Array[Node] = _ui.get_node("%NodeGrid").get_children()
	for i: int in range(0, cells.size(), 5):
		if (cells[i] as Label).text == id:
			return cells.slice(i, i + 5)
	return []


func _pools() -> Array[String]:
	var texts: Array[String] = []
	for label: Label in _ui.get_node("%PoolList").get_children():
		texts.append(label.text)
	return texts


func _errors() -> Array[String]:
	var texts: Array[String] = []
	for label: Label in _ui.get_node("%ErrorList").get_children():
		texts.append(label.text)
	return texts


func _errors_title() -> String:
	return (_ui.get_node("%Tabs") as TabContainer).get_tab_title(WeavlyDebugUI.ERRORS_TAB)


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	_ui._unhandled_input(event)


func test_the_scene_starts_hidden() -> void:
	var fresh: WeavlyDebugUI = auto_free(SCENE.instantiate())
	assert_bool(fresh.visible).is_false()


func test_a_missing_toggle_action_is_added_on_f3() -> void:
	assert_bool(InputMap.has_action(TOGGLE)).is_true()
	var events: Array[InputEvent] = InputMap.action_get_events(TOGGLE)
	assert_int(events.size()).is_equal(1)
	assert_int((events[0] as InputEventKey).keycode).is_equal(KEY_F3)


func test_the_toggle_action_shows_and_hides_the_overlay() -> void:
	_press(TOGGLE)
	assert_bool(_ui.visible).is_false()
	_press(TOGGLE)
	assert_bool(_ui.visible).is_true()


func test_only_the_toggle_action_toggles_and_it_doesnt_reach_the_game() -> void:
	_press(&"ui_accept")
	assert_bool(_ui.visible).is_true()
	assert_bool(handles_input(_ui._unhandled_input, action_pressed(TOGGLE))).is_true()
	assert_bool(_ui.visible).is_false()


func test_showing_the_overlay_refreshes_it() -> void:
	_ui.visible = false
	_engine.variable_service.set_variable("gold", 9.0)
	_ui.visible = true
	assert_str((_variable_editor("gold") as LineEdit).text).is_equal("9")


func test_status_shows_idle_and_the_current_node_and_line() -> void:
	assert_str(_status()).is_equal("idle")
	_engine.start("start")
	_ui.refresh()
	assert_str(_status()).is_equal("running, node start at debug.wvl:14")
	_engine.next()
	_ui.refresh()
	assert_str(_status()).is_equal("running, node start at debug.wvl:16")


func test_variables_show_sorted_with_their_types_and_values() -> void:
	(
		assert_array(_rows("%VariableGrid", 3))
		. is_equal(
			[
				["area", "pool", "city"],
				["brave", "flag", false],
				["gold", "number", "3"],
				["name", "string", "Robin"],
				["partner", "slot", "pair"],
				["target", "node", "gate"],
			]
		)
	)


func test_an_extern_variable_shows_once_it_has_a_value() -> void:
	_engine.variable_service.set_variable("secret", 42.0)
	_ui.refresh()
	(
		assert_array(_rows("%VariableGrid", 3).map(func(row: Array) -> String: return row[0]))
		. is_equal(["area", "brave", "gold", "name", "partner", "secret", "target"])
	)
	assert_str((_variable_editor("secret") as LineEdit).text).is_equal("42")


func test_variables_follow_the_dialogue() -> void:
	_engine.start("start")
	_engine.next()
	_ui.refresh()
	assert_str((_variable_editor("gold") as LineEdit).text).is_equal("5")


func test_numbers_show_exactly() -> void:
	_engine.variable_service.set_variable("gold", 1.0 / 3.0)
	_ui.refresh()
	assert_str((_variable_editor("gold") as LineEdit).text).is_equal(str(1.0 / 3.0))


func test_editing_a_number_sets_it() -> void:
	var edit: LineEdit = _variable_editor("gold")
	edit.text = " 7.5 "
	edit.focus_exited.emit()
	assert_float(_engine.variable_service.get_variable("gold")).is_equal(7.5)
	assert_str(edit.text).is_equal("7.5")


func test_submitting_an_edit_sets_it() -> void:
	var edit: LineEdit = _variable_editor("gold")
	edit.grab_focus()
	edit.text = "8"
	edit.text_submitted.emit(edit.text)
	assert_bool(edit.has_focus()).is_false()
	assert_float(_engine.variable_service.get_variable("gold")).is_equal(8.0)


func test_editing_a_number_with_text_keeps_the_value() -> void:
	var edit: LineEdit = _variable_editor("gold")
	edit.text = "lots"
	edit.focus_exited.emit()
	assert_float(_engine.variable_service.get_variable("gold")).is_equal(3.0)
	assert_str(edit.text).is_equal("3")


func test_editing_a_string_sets_it() -> void:
	var edit: LineEdit = _variable_editor("name")
	edit.text = "Sam"
	edit.focus_exited.emit()
	assert_str(_engine.variable_service.get_variable("name")).is_equal("Sam")


func _items(names: OptionButton) -> Array[String]:
	var items: Array[String] = []
	for i: int in names.item_count:
		items.append(names.get_item_text(i))
	return items


func test_name_variables_offer_the_declared_names_of_their_type() -> void:
	assert_array(_items(_variable_editor("target"))).is_equal(
		["ann", "bob", "broken", "gate", "start"]
	)
	assert_array(_items(_variable_editor("area"))).is_equal(["city"])
	assert_array(_items(_variable_editor("partner"))).is_equal(["pair"])


func test_choosing_a_name_sets_it() -> void:
	var names: OptionButton = _variable_editor("target")
	var index: int = _items(names).find("start")
	names.select(index)
	names.item_selected.emit(index)
	assert_str(_engine.variable_service.get_variable("target")).is_equal("start")
	assert_str(names.text).is_equal("start")


func test_name_variables_follow_the_dialogue() -> void:
	_engine.variable_service.set_variable("target", "bob")
	_ui.refresh()
	assert_str((_variable_editor("target") as OptionButton).text).is_equal("bob")


func test_toggling_a_flag_sets_it() -> void:
	var check: CheckBox = _variable_editor("brave")
	assert_str(check.text).is_equal("false")
	check.button_pressed = true
	assert_bool(_engine.variable_service.get_variable("brave")).is_true()
	assert_str(check.text).is_equal("true")


func test_nodes_show_their_location_and_counts() -> void:
	_engine.start("start")
	_engine.next()
	_engine.next()
	_ui.refresh()
	var rows: Array[Array] = _rows("%NodeGrid", 5)
	(
		assert_array(rows.map(func(row: Array) -> String: return row[0]))
		. is_equal(["ann", "bob", "broken", "gate", "start"])
	)
	assert_array(rows[4]).is_equal(["start", "debug.wvl:13", "1 visits", "0 skips", "Start"])
	assert_array(rows[3]).is_equal(["gate", "debug.wvl:20", "0 visits", "0 skips", "Start"])


func test_the_current_node_is_marked() -> void:
	_engine.start("start")
	_ui.refresh()
	var current: Label = _node_cells("start")[0]
	assert_str(current.theme_type_variation).is_equal("WeavlyDebugCurrent")
	assert_str((_node_cells("gate")[0] as Label).theme_type_variation).is_empty()


func test_skip_counts_follow_the_pools() -> void:
	_engine.list_pool(["city"], 1)
	_ui.refresh()
	assert_str((_node_cells("ann")[3] as Label).text).is_equal("1 skips")


func test_the_filter_hides_other_nodes() -> void:
	(_ui.get_node("%NodeFilter") as LineEdit).text = "B"
	(_ui.get_node("%NodeFilter") as LineEdit).text_changed.emit("B")
	(
		assert_array(_rows("%NodeGrid", 5).map(func(row: Array) -> String: return row[0]))
		. is_equal(["bob", "broken"])
	)


func test_start_jumps_to_a_node() -> void:
	_engine.start("start")
	(_node_cells("gate")[4] as Button).pressed.emit()
	assert_bool(_engine.is_running()).is_true()
	assert_str(_engine.current_node_id).is_equal("gate")
	assert_str(_status()).is_equal("running, node gate at debug.wvl:21")


func test_pools_show_what_list_pool_would_return() -> void:
	_show_tab(WeavlyDebugUI.POOLS_TAB)
	assert_array(_pools()).is_equal(["city", "bob, ann"])


func test_pools_follow_variable_changes() -> void:
	_show_tab(WeavlyDebugUI.POOLS_TAB)
	_engine.variable_service.set_variable("gold", 1.0)
	assert_array(_pools()).is_equal(["city", "ann"])


func test_peeking_doesnt_change_skip_counts() -> void:
	_show_tab(WeavlyDebugUI.POOLS_TAB)
	_ui.refresh()
	assert_int(_engine.node_service.get_skip_count("ann")).is_equal(0)


func test_pools_arent_peeked_on_other_tabs() -> void:
	_engine.variable_service.set_variable("gold", 1.0)
	assert_array(_pools()).is_empty()


func test_runtime_errors_are_listed_with_their_location() -> void:
	_engine.start("broken")
	assert_logged(["secret"])
	assert_int(_errors().size()).is_equal(1)
	assert_str(_errors()[0]).starts_with("debug.wvl:25: ")
	assert_str(_errors()[0]).contains("secret")
	assert_str(_errors_title()).is_equal("Errors (1)")


func test_errors_beyond_the_limit_drop_the_oldest() -> void:
	_ui.max_errors = 2
	for message: String in ["one", "two", "three"]:
		_engine.runtime_error.emit(message, "", 0)
	assert_array(_errors()).is_equal(["two", "three"])
	assert_str(_errors_title()).is_equal("Errors (3)")


func test_clearing_errors() -> void:
	_engine.runtime_error.emit("one", "", 0)
	(_ui.get_node("%ClearErrors") as Button).pressed.emit()
	assert_array(_errors()).is_empty()
	assert_str(_errors_title()).is_equal("Errors")


func test_disconnecting_the_engine_clears_the_overlay() -> void:
	_engine.runtime_error.emit("one", "", 0)
	_ui.engine = null
	assert_array(_rows("%VariableGrid", 3)).is_empty()
	assert_array(_rows("%NodeGrid", 5)).is_empty()
	assert_array(_errors()).is_empty()
	assert_str(_status()).is_empty()
