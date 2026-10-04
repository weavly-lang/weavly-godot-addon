# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# The visual novel UI against the compiler-built fixture in novel/src/novel.wvl.

const FIXTURE = "res://test/fixtures/ui/novel"
const SCENE = preload("res://addons/weavly/ui/novel/weavly_novel_ui.tscn")

var _engine: WeavlyEngine
var _ui: WeavlyNovelUI
# What the fixture's open() returns.
var _door_open: bool


func before_test() -> void:
	_engine = WeavlyEngine.new()
	_engine.dialogue_path = FIXTURE + "/build"
	_engine.character_path = FIXTURE + "/characters"
	add_child(auto_free(_engine))
	_door_open = true
	_engine.register_function("open", func() -> bool: return _door_open)
	_ui = auto_free(SCENE.instantiate())
	_ui.engine = _engine
	_ui.characters_per_second = 0.0
	add_child(_ui)


func _nameplate() -> Label:
	return _ui.get_node("%Nameplate")


func _text() -> RichTextLabel:
	return _ui.get_node("%Text")


func _choices() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _ui.get_node("%Choices").get_children():
		buttons.append(child)
	return buttons


func _click() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_ui._gui_input(event)


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	_ui._unhandled_input(event)


# Through the viewport, so focused buttons get the key before the UI does.
func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		get_viewport().push_input(event)


func _advance(times: int) -> void:
	for i: int in times:
		_ui.advance()


func test_hidden_until_a_line_shows() -> void:
	assert_bool(_ui.visible).is_false()
	_engine.start("start")
	assert_bool(_ui.visible).is_true()


func test_novel_character_uses_its_name_and_color() -> void:
	_engine.start("start")
	assert_str(_text().text).is_equal("Hello there.")
	assert_bool(_nameplate().visible).is_true()
	assert_str(_nameplate().text).is_equal("Guide")
	assert_that(_nameplate().get_theme_color(&"font_color")).is_equal(Color(0.4, 0.8, 1, 1))


func test_narration_hides_the_nameplate() -> void:
	_engine.start("start")
	_advance(1)
	assert_str(_text().text).is_equal("The wind picks up.")
	assert_bool(_nameplate().visible).is_false()


func test_plain_character_uses_the_theme_color() -> void:
	_engine.start("start")
	_advance(2)
	assert_str(_nameplate().text).is_equal("Innkeeper")
	assert_bool(_nameplate().has_theme_color_override(&"font_color")).is_false()
	assert_that(_nameplate().get_theme_color(&"font_color")).is_equal(Color(1, 0.85, 0.5, 1))


func test_speaker_without_a_character_shows_the_name_as_written() -> void:
	_engine.start("start")
	_advance(3)
	assert_str(_nameplate().text).is_equal("stranger")


func test_reveal_completes_then_advances() -> void:
	_ui.characters_per_second = 4.0
	_engine.start("start")
	assert_bool(_ui.is_revealing()).is_true()
	assert_bool(_ui.is_processing()).is_true()
	assert_int(_text().visible_characters).is_equal(0)
	_ui._process(0.5)
	assert_int(_text().visible_characters).is_equal(2)
	_ui.advance()
	assert_bool(_ui.is_revealing()).is_false()
	assert_bool(_ui.is_processing()).is_false()
	assert_int(_text().visible_characters).is_equal(-1)
	assert_str(_text().text).is_equal("Hello there.")
	_ui.advance()
	assert_str(_text().text).is_equal("The wind picks up.")


func test_reveal_finishes_on_its_own() -> void:
	_ui.characters_per_second = 4.0
	_engine.start("start")
	_ui._process(10.0)
	assert_bool(_ui.is_revealing()).is_false()
	assert_int(_text().visible_characters).is_equal(-1)


func test_click_and_input_action_advance() -> void:
	_engine.start("start")
	_click()
	assert_str(_text().text).is_equal("The wind picks up.")
	_press(&"ui_accept")
	assert_str(_text().text).is_equal("Welcome.")


func test_clicks_and_keys_the_ui_uses_dont_reach_the_game() -> void:
	_engine.start("start")
	assert_bool(handles_input(_ui._gui_input, mouse_button(MOUSE_BUTTON_LEFT))).is_true()
	assert_bool(handles_input(_ui._unhandled_input, action_pressed(&"ui_accept"))).is_true()
	_advance(2)
	assert_bool(handles_input(_ui._unhandled_input, action_pressed(&"ui_down"))).is_true()


func test_only_pressing_the_left_button_advances() -> void:
	_engine.start("start")
	_ui._gui_input(mouse_button(MOUSE_BUTTON_RIGHT))
	_ui._gui_input(mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_str(_text().text).is_equal("Hello there.")


func test_options_show_as_buttons() -> void:
	_engine.start("start")
	_advance(4)
	var buttons: Array[Button] = _choices()
	(
		assert_array(buttons.map(func(button: Button) -> String: return button.text))
		. is_equal(["Wave"])
	)


func test_advancing_doesnt_skip_a_choice() -> void:
	_engine.start("start")
	_advance(5)
	assert_int(_choices().size()).is_equal(1)
	assert_str(_text().text).is_equal("Who are you?")


func test_choosing_an_option_continues() -> void:
	_engine.start("start")
	_advance(4)
	_choices()[0].pressed.emit()
	assert_array(_choices()).is_empty()
	assert_str(_text().text).is_equal("You wave.")


func test_options_open_without_focus() -> void:
	_engine.start("start")
	_advance(4)
	assert_bool(_choices().any(func(button: Button) -> bool: return button.has_focus())).is_false()


func test_navigating_focuses_the_first_option() -> void:
	_engine.start("start")
	_advance(4)
	_press(&"ui_down")
	assert_bool(_choices()[0].has_focus()).is_true()


func test_advance_action_focuses_instead_of_choosing() -> void:
	_engine.start("start")
	_advance(4)
	_press(&"ui_accept")
	assert_bool(_choices()[0].has_focus()).is_true()
	assert_int(_choices().size()).is_equal(1)


func test_keys_choose_the_focused_option() -> void:
	_engine.start("crossroads")
	await get_tree().process_frame
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	assert_bool(_choices()[1].has_focus()).is_true()
	_press_key(KEY_ENTER)
	assert_str(_text().text).is_equal("You go right.")


func test_hovering_selects_an_option() -> void:
	_engine.start("crossroads")
	_choices()[1].mouse_entered.emit()
	assert_bool(_choices()[1].has_focus()).is_true()


func test_keys_choose_the_hovered_option() -> void:
	_engine.start("crossroads")
	_choices()[1].mouse_entered.emit()
	_press_key(KEY_ENTER)
	assert_str(_text().text).is_equal("You go right.")


func test_bbcode_is_shown_as_written_in_lines_and_options() -> void:
	_engine.start("formatted")
	assert_str(_text().get_parsed_text()).is_equal("Hello [b]world[/b].")
	_ui.advance()
	assert_str(_choices()[0].text).is_equal("[i]Wave[/i]")


func test_hidden_after_the_dialogue_finishes() -> void:
	_engine.start("waved")
	_ui.advance()
	assert_bool(_engine.is_running()).is_false()
	assert_bool(_ui.visible).is_false()


func test_loading_a_state_clears_the_ui() -> void:
	_engine.start("start")
	_engine.reset_state()
	assert_bool(_ui.visible).is_false()
	assert_str(_text().text).is_empty()


func test_loading_a_state_stops_a_reveal() -> void:
	_ui.characters_per_second = 4.0
	_engine.start("start")
	_engine.reset_state()
	assert_bool(_ui.is_revealing()).is_false()
	assert_bool(_ui.is_processing()).is_false()


func test_loading_a_state_mid_dialogue_shows_the_replayed_node() -> void:
	_engine.start("start")
	var state: Dictionary = _engine.get_state()
	_advance(4)
	_engine.set_state(state)
	assert_array(_choices()).is_empty()
	assert_str(_text().text).is_equal("Hello there.")


func test_disconnecting_the_engine_hides_and_stops_listening() -> void:
	_engine.start("start")
	_ui.engine = null
	assert_bool(_ui.visible).is_false()
	_engine.next()
	assert_bool(_ui.visible).is_false()
	assert_str(_text().text).is_empty()


# =====================
# Locked options
# =====================


func test_a_locked_option_shows_disabled_and_unlocks_when_its_state_changes() -> void:
	_engine.start("gated")
	assert_str(_choices()[0].text).is_equal("The vault is sealed")
	assert_bool(_choices()[0].disabled).is_true()
	_engine.set_variable("has_code", true)
	assert_str(_choices()[0].text).is_equal("Open the vault")
	assert_bool(_choices()[0].disabled).is_false()
	_choices()[0].pressed.emit()
	assert_str(_text().text).is_equal("Opened.")


func test_advancing_continues_past_a_block_where_nothing_can_be_chosen() -> void:
	_engine.start("sealed")
	assert_bool(_choices()[0].disabled).is_true()
	_ui.advance()
	assert_str(_text().text).is_equal("You walk on.")
	assert_array(_choices()).is_empty()


func test_a_refused_choice_keeps_the_choices_and_shows_the_change() -> void:
	_engine.start("door")
	_door_open = false
	_choices()[0].pressed.emit()
	assert_logged([], ["Can't choose option 'Open' because it's locked."])
	assert_bool(_choices()[0].visible).is_false()
	assert_bool(_choices()[1].visible).is_true()
	_choices()[1].pressed.emit()
	assert_str(_engine.current_node_id).is_equal("waved")
