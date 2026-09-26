# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# The passage UI against the compiler-built fixture in passage/src/passage.wvl.

const FIXTURE = "res://test/fixtures/ui/passage"
const SCENE = preload("res://addons/weavly/ui/passage/weavly_passage_ui.tscn")

var _engine: WeavlyDefaultEngine
var _ui: WeavlyPassageUI
var _events: Array[String]
var _window_size: Vector2i


# Key navigation skips links clipped by the scroll area, so the tiny headless window won't do.
func before() -> void:
	_window_size = get_window().size
	get_window().size = Vector2i(1280, 720)


func after() -> void:
	get_window().size = _window_size


func before_test() -> void:
	_events = []
	_engine = WeavlyDefaultEngine.new()
	_engine.dialogue_path = FIXTURE + "/build"
	_engine.video_path = FIXTURE + "/build"
	_engine.image_path = FIXTURE + "/build"
	_engine.character_path = FIXTURE + "/characters"
	_engine.variable_path = FIXTURE + "/build"
	add_child(auto_free(_engine))
	_ui = auto_free(SCENE.instantiate())
	_ui.engine = _engine
	_ui.command_rendered.connect(
		func(command: WeavlyModel.CommandStatement) -> void:
			_events.append("command:%s %s" % [command.id, command.values])
	)
	_ui.finished.connect(func() -> void: _events.append("finished"))
	add_child(_ui)


# Replaced passages are queue_free()d, so let them go before gdUnit counts orphans.
func after_test() -> void:
	await get_tree().process_frame


# Each passage as its texts, option lists as arrays of option texts, chosen options as "> text".
func _describe() -> Array:
	var passages: Array = []
	for passage: Node in _ui.get_node("%Passages").get_children():
		var items: Array = []
		for child: Node in passage.get_children():
			if child is RichTextLabel:
				items.append(child.get_parsed_text())
			elif child is WeavlyChoiceList:
				items.append(
					child.get_children().map(func(link: LinkButton) -> String: return link.text)
				)
			elif child is Label:
				items.append("> " + child.text)
		passages.append(items)
	return passages


func _link(text: String) -> LinkButton:
	var passages: Array[Node] = _ui.get_node("%Passages").get_children()
	for child: Node in passages[-1].get_children():
		if child is WeavlyChoiceList:
			for link: LinkButton in child.get_children():
				if link.text == text:
					return link
	return null


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		get_viewport().push_input(event)


func test_hidden_until_a_passage_shows() -> void:
	assert_bool(_ui.visible).is_false()
	_ui.show_passage("tavern")
	assert_bool(_ui.visible).is_true()


func test_shows_lines_and_option_blocks_in_order() -> void:
	_ui.show_passage("tavern")
	(
		assert_array(_describe())
		. is_equal(
			[
				[
					"Guide: Welcome, you have 0 gold.",
					["Buy a drink", "Leave", "Gamble (closed)"],
					"Stranger: Mind the fire.",
					["Warm up"],
				]
			]
		)
	)


func test_hints_cant_be_clicked_or_selected() -> void:
	_ui.show_passage("tavern")
	var hint: LinkButton = _link("Gamble (closed)")
	assert_bool(hint.disabled).is_true()
	assert_int(hint.focus_mode).is_equal(Control.FOCUS_NONE)


func test_commands_are_emitted_in_order() -> void:
	_ui.show_passage("tavern")
	assert_array(_events).is_equal(['command:header ["Tavern"]'])


func test_following_a_link_into_the_next_node() -> void:
	_ui.show_passage("tavern")
	_link("Buy a drink").pressed.emit()
	assert_array(_describe()).is_equal([["The drink is cold.", "The barkeep nods.", ["Back"]]])
	assert_float(_engine.variable_service.get_variable("gold")).is_equal(1.0)


func test_a_link_from_a_later_option_block() -> void:
	_ui.show_passage("tavern")
	_link("Warm up").pressed.emit()
	assert_array(_describe()).is_equal([["You warm up.", ["Stay (too hot)"]]])


func test_append_keeps_earlier_passages() -> void:
	_ui.append = true
	_ui.show_passage("tavern")
	_link("Buy a drink").pressed.emit()
	(
		assert_array(_describe())
		. is_equal(
			[
				["Guide: Welcome, you have 0 gold.", "Stranger: Mind the fire.", "> Buy a drink"],
				["The drink is cold.", "The barkeep nods.", ["Back"]],
			]
		)
	)


func test_a_passage_without_options_finishes() -> void:
	_ui.show_passage("tavern")
	_link("Leave").pressed.emit()
	assert_array(_describe()).is_equal([["The street is empty."]])
	assert_array(_events).contains(["finished"])


func test_a_passage_of_only_hints_finishes() -> void:
	_ui.show_passage("fire")
	assert_array(_events).is_equal(["finished"])


func test_a_passage_with_options_doesnt_finish() -> void:
	_ui.show_passage("bar")
	assert_array(_events).is_empty()


func test_refuses_while_a_dialogue_runs() -> void:
	_engine.start("street")
	_ui.show_passage("tavern")
	assert_bool(_ui.visible).is_false()
	assert_logged([], ["Can't show a passage while a dialogue runs."])


func test_hovering_selects_a_link() -> void:
	_ui.show_passage("tavern")
	_link("Leave").mouse_entered.emit()
	assert_bool(_link("Leave").has_focus()).is_true()


func test_keys_select_and_choose_a_link() -> void:
	_ui.show_passage("bar")
	await get_tree().process_frame
	_press_key(KEY_DOWN)
	assert_bool(_link("Back").has_focus()).is_true()
	_press_key(KEY_ENTER)
	assert_str(_describe()[0][0]).is_equal("Guide: Welcome, you have 0 gold.")


func test_keys_move_between_option_blocks_and_choose_the_focused_link() -> void:
	_ui.show_passage("tavern")
	await get_tree().process_frame
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	assert_bool(_link("Warm up").has_focus()).is_true()
	_press_key(KEY_ENTER)
	assert_str(_describe()[0][0]).is_equal("You warm up.")


func test_bbcode_is_shown_literally_by_default() -> void:
	_ui.show_passage("formatted")
	assert_array(_describe()).is_equal([["Hello [b]world[/b]."]])


func test_bbcode_enabled_renders_it() -> void:
	_ui.bbcode_enabled = true
	_ui.show_passage("formatted")
	assert_array(_describe()).is_equal([["Hello world."]])


func test_loading_a_state_clears_the_ui() -> void:
	_ui.show_passage("tavern")
	_engine.reset_state()
	assert_bool(_ui.visible).is_false()
	assert_array(_describe()).is_empty()


func test_clear_hides_and_removes_passages() -> void:
	_ui.show_passage("tavern")
	_ui.clear()
	assert_bool(_ui.visible).is_false()
	assert_array(_describe()).is_empty()


func test_disconnecting_the_engine_clears_and_stops_rendering() -> void:
	_ui.show_passage("tavern")
	_ui.engine = null
	assert_bool(_ui.visible).is_false()
	_ui.show_passage("tavern")
	assert_array(_describe()).is_empty()
