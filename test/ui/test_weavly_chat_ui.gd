# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# The chat UI against the compiler-built fixture in chat/src/chat.wvl.

const FIXTURE = "res://test/fixtures/ui/chat"
const SCENE = preload("res://addons/weavly/ui/chat/weavly_chat_ui.tscn")

var _engine: WeavlyDefaultEngine
var _ui: WeavlyChatUI


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
	_ui.player_character = "me"
	add_child(_ui)


# Removed messages are queue_free()d, so let them go before gdUnit counts orphans.
func after_test() -> void:
	await get_tree().process_frame


func _rows() -> Array[HBoxContainer]:
	var rows: Array[HBoxContainer] = []
	for child: Node in _ui.get_node("%Messages").get_children():
		if child != _ui.get_node("%Typing"):
			rows.append(child)
	return rows


func _find(node: Node, type: String) -> Node:
	for child: Node in node.get_children():
		if child.is_class(type):
			return child
		var found: Node = _find(child, type)
		if found != null:
			return found
	return null


# Each message as "left Name: text", "left: text" without a name, "right: text" or "center: text".
func _describe() -> Array[String]:
	var described: Array[String] = []
	for row: HBoxContainer in _rows():
		var text: String = (_find(row, "RichTextLabel") as RichTextLabel).get_parsed_text()
		match row.alignment:
			BoxContainer.ALIGNMENT_BEGIN:
				var name_label: Label = _find(row, "Label")
				var speaker: String = " " + name_label.text if name_label != null else ""
				described.append("left%s: %s" % [speaker, text])
			BoxContainer.ALIGNMENT_END:
				described.append("right: " + text)
			_:
				described.append("center: " + text)
	return described


func _replies() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _ui.get_node("%Replies").get_children():
		buttons.append(child)
	return buttons


func _typing() -> bool:
	return _ui.get_node("%Typing").visible


func _wait_out() -> void:
	_ui._process(10.0)


func _click() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_ui._on_phone_input(event)


func test_hidden_until_the_first_message() -> void:
	assert_bool(_ui.visible).is_false()
	_engine.start("start")
	assert_bool(_ui.visible).is_true()


func test_another_characters_message_waits_behind_the_typing_indicator() -> void:
	_engine.start("start")
	assert_bool(_typing()).is_true()
	assert_array(_describe()).is_empty()
	_wait_out()
	assert_array(_describe()).is_equal(["left Mara: are you still up?"])


func test_the_typing_wait_follows_the_text_length_within_limits() -> void:
	_ui.typing_speed = 10.0
	_ui.min_wait = 0.5
	_ui.max_wait = 5.0
	_engine.start("start")
	_ui._process(1.6)
	assert_array(_describe()).is_empty()
	_ui._process(0.2)
	assert_array(_describe()).is_equal(["left Mara: are you still up?"])
	assert_float(_ui._typing_wait("ok")).is_equal(0.5)
	assert_float(_ui._typing_wait("x".repeat(100))).is_equal(5.0)


func test_a_click_skips_the_wait() -> void:
	_engine.start("start")
	_click()
	assert_array(_describe()).is_equal(["left Mara: are you still up?"])


func test_the_advance_action_skips_the_wait() -> void:
	_engine.start("start")
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	_ui._unhandled_input(event)
	assert_array(_describe()).is_equal(["left Mara: are you still up?"])


func test_player_lines_and_narration_wait_briefly_without_the_indicator() -> void:
	_engine.start("start")
	_wait_out()
	assert_bool(_ui.is_waiting()).is_true()
	assert_bool(_typing()).is_false()
	_wait_out()
	assert_bool(_typing()).is_false()
	_wait_out()
	assert_array(_describe()).is_equal(
		["left Mara: are you still up?", "right: yeah why", "center: It's 21:04."]
	)


func test_a_run_of_messages_shows_the_name_and_avatar_once() -> void:
	_engine.start("burst")
	for i: int in 4:
		_wait_out()
	assert_array(_describe()).is_equal(
		["left Mara: one", "left: two", "center: It's late.", "left Mara: three"]
	)
	var avatars: Array = _rows().map(
		func(row: HBoxContainer) -> Variant:
			var avatar: TextureRect = _find(row, "TextureRect")
			return null if avatar == null else avatar.texture != null
	)
	assert_array(avatars).is_equal([true, false, null, true])


func test_a_speaker_without_a_character_shows_the_name_as_written() -> void:
	_engine.start("start")
	for i: int in 4:
		_wait_out()
	assert_str(_describe()[-1]).is_equal("left stranger: hello?")


func test_a_chat_character_gets_its_avatar_and_bubble_color() -> void:
	_engine.start("start")
	_wait_out()
	var row: HBoxContainer = _rows()[0]
	assert_object(_find(row, "TextureRect")).is_not_null()
	var bubble: PanelContainer = _find(row, "PanelContainer")
	var style: StyleBoxFlat = bubble.get_theme_stylebox(&"panel")
	assert_that(style.bg_color).is_equal(Color(0.5, 0.2, 0.4, 1))


func test_a_plain_character_uses_the_theme_bubble() -> void:
	_engine.start("start")
	for i: int in 4:
		_wait_out()
	var row: HBoxContainer = _rows()[-1]
	assert_object(_find(row, "TextureRect")).is_null()
	var bubble: PanelContainer = _find(row, "PanelContainer")
	assert_bool(bubble.has_theme_stylebox_override(&"panel")).is_false()


func test_replies_show_with_hints_disabled() -> void:
	_engine.start("start")
	for i: int in 4:
		_wait_out()
	var replies: Array[Button] = _replies()
	(
		assert_array(replies.map(func(button: Button) -> String: return button.text))
		. is_equal(["what happened?", "going to sleep", "call her (no signal)"])
	)
	assert_bool(replies[2].disabled).is_true()
	assert_bool(_ui.is_waiting()).is_false()


func test_the_chosen_reply_becomes_a_player_bubble() -> void:
	_engine.start("start")
	for i: int in 4:
		_wait_out()
	_replies()[0].pressed.emit()
	assert_array(_replies()).is_empty()
	assert_str(_describe()[-1]).is_equal("right: what happened?")
	_wait_out()
	assert_str(_describe()[-1]).is_equal("left Mara: you won't believe it")


func test_a_reply_bar_of_only_hints_waits_for_continue() -> void:
	_engine.start("hints")
	_wait_out()
	(
		assert_array(_replies().map(func(button: Button) -> bool: return button.disabled))
		. is_equal([true])
	)
	var next: Button = _ui.get_node("%Continue")
	assert_bool(next.visible).is_true()
	assert_bool(_ui.is_waiting()).is_false()
	_click()
	_wait_out()
	assert_int(_replies().size()).is_equal(1)
	next.pressed.emit()
	assert_array(_replies()).is_empty()
	assert_bool(next.visible).is_false()
	_wait_out()
	assert_str(_describe()[-1]).is_equal("left: nvm")


func test_bubbles_fit_short_text_and_wrap_long_text() -> void:
	_engine.start("long")
	_wait_out()
	var long_text: RichTextLabel = _find(_rows()[0], "RichTextLabel")
	assert_float(long_text.custom_minimum_size.x).is_equal(_ui.max_bubble_width)
	_engine.start("start")
	_wait_out()
	var short_text: RichTextLabel = _find(_rows()[-1], "RichTextLabel")
	assert_float(short_text.custom_minimum_size.x).is_less(_ui.max_bubble_width)


func test_the_conversation_stays_after_the_dialogue_finishes() -> void:
	_engine.start("sleep")
	_wait_out()
	assert_bool(_engine.is_running()).is_false()
	assert_bool(_ui.visible).is_true()
	assert_array(_describe()).is_equal(["left Mara: ok good night"])


func test_keys_select_a_reply() -> void:
	_engine.start("start")
	for i: int in 4:
		_wait_out()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_down"
	event.pressed = true
	_ui._unhandled_input(event)
	assert_bool(_replies()[0].has_focus()).is_true()


func test_keys_and_hover_select_continue() -> void:
	_engine.start("hints")
	_wait_out()
	var next: Button = _ui.get_node("%Continue")
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	_ui._unhandled_input(event)
	assert_bool(next.has_focus()).is_true()
	assert_int(_replies().size()).is_equal(1)
	next.mouse_exited.emit()
	assert_bool(next.has_focus()).is_false()
	next.mouse_entered.emit()
	assert_bool(next.has_focus()).is_true()


func test_clear_hides_and_empties_the_conversation() -> void:
	_engine.start("start")
	_wait_out()
	_ui.clear()
	assert_bool(_ui.visible).is_false()
	assert_array(_describe()).is_empty()


func test_loading_a_state_clears_the_ui() -> void:
	_engine.start("start")
	_wait_out()
	_engine.reset_state()
	assert_bool(_ui.visible).is_false()
	assert_array(_describe()).is_empty()


func test_disconnecting_the_engine_clears_and_stops_listening() -> void:
	_engine.start("start")
	_ui.engine = null
	assert_bool(_ui.visible).is_false()
	assert_bool(_ui.is_waiting()).is_false()
	_engine.next()
	assert_array(_describe()).is_empty()
