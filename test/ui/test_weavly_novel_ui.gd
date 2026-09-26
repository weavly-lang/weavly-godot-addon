extends WeavlyTestSuite

# The visual novel UI against the compiler-built fixture in novel/src/novel.wvl.

const FIXTURE = "res://test/fixtures/ui/novel"
const SCENE = preload("res://addons/weavly/ui/novel/weavly_novel_ui.tscn")

var _engine: WeavlyDefaultEngine
var _ui: WeavlyNovelUI


func before_test() -> void:
	_engine = WeavlyDefaultEngine.new()
	_engine.dialogue_path = FIXTURE + "/build"
	_engine.video_path = FIXTURE + "/build"
	_engine.image_path = FIXTURE + "/build"
	_engine.character_path = FIXTURE + "/characters"
	_engine.variable_path = FIXTURE + "/build"
	add_child(auto_free(_engine))
	_ui = auto_free(SCENE.instantiate())
	_ui.engine = _engine
	_ui.characters_per_second = 0.0
	add_child(_ui)


func _nameplate() -> Label:
	return _ui.get_node("%Nameplate")


func _text() -> Label:
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


func _press_advance_action() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	_ui._unhandled_input(event)


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
	assert_int(_text().visible_characters).is_equal(0)
	_ui._process(0.5)
	assert_int(_text().visible_characters).is_equal(2)
	_ui.advance()
	assert_bool(_ui.is_revealing()).is_false()
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
	_press_advance_action()
	assert_str(_text().text).is_equal("Welcome.")


func test_options_show_hints_disabled() -> void:
	_engine.start("start")
	_advance(4)
	var buttons: Array[Button] = _choices()
	(
		assert_array(buttons.map(func(button: Button) -> String: return button.text))
		. is_equal(["Wave", "Fight (too tired)"])
	)
	assert_bool(buttons[0].disabled).is_false()
	assert_bool(buttons[1].disabled).is_true()


func test_advancing_doesnt_skip_a_choice() -> void:
	_engine.start("start")
	_advance(5)
	assert_int(_choices().size()).is_equal(2)
	assert_str(_text().text).is_equal("Who are you?")


func test_choosing_an_option_continues() -> void:
	_engine.start("start")
	_advance(4)
	_choices()[0].pressed.emit()
	assert_array(_choices()).is_empty()
	assert_str(_text().text).is_equal("You wave.")


func test_only_hints_wait_for_advance() -> void:
	_engine.start("hints")
	(
		assert_array(_choices().map(func(button: Button) -> bool: return button.disabled))
		. is_equal([true])
	)
	_ui.advance()
	assert_array(_choices()).is_empty()
	assert_str(_text().text).is_equal("You walk on.")


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
