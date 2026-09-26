# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# The card UI against the compiler-built fixture in card/src/card.wvl.

const FIXTURE = "res://test/fixtures/ui/card"
const SCENE = preload("res://addons/weavly/ui/card/weavly_card_ui.tscn")

var _engine: WeavlyDefaultEngine
var _ui: WeavlyCardUI
var _events: Array[String]
var _window_size: Vector2i


# Key navigation needs the cards on screen, which the tiny headless window can't show.
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
	_ui.hand_empty.connect(func() -> void: _events.append("hand_empty"))
	add_child(_ui)


# Removed cards are queue_free()d, so let them go before gdUnit counts orphans.
func after_test() -> void:
	await get_tree().process_frame


func _cards(container: String = "%Hand") -> Array[WeavlyCard]:
	var cards: Array[WeavlyCard] = []
	for child: Node in _ui.get_node(container).get_children():
		if child is WeavlyCard:
			cards.append(child)
	return cards


# A card as its texts, with option lists as arrays of option texts.
func _describe(card: WeavlyCard) -> Array:
	var items: Array = []
	for child: Node in card.get_child(0).get_children():
		if child is RichTextLabel:
			items.append(child.get_parsed_text())
		elif child is WeavlyChoiceList:
			items.append(
				child.get_children().map(func(button: Button) -> String: return button.text)
			)
	return items


func _hand() -> Array:
	return _cards().map(_describe)


func _outcome() -> Array:
	return _describe(_cards("%Outcome")[0])


func _button(card: WeavlyCard, text: String) -> Button:
	for child: Node in card.get_child(0).get_children():
		if child is WeavlyChoiceList:
			for button: Button in child.get_children():
				if button.text == text:
					return button
	return null


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		get_viewport().push_input(event)


func test_hidden_until_dealt() -> void:
	assert_bool(_ui.visible).is_false()
	_ui.deal(["city"])
	assert_bool(_ui.visible).is_true()


func test_deals_the_first_cards_in_selection_order() -> void:
	_ui.deal(["city"])
	(
		assert_array(_hand())
		. is_equal(
			[
				["Guide: A stranger waves you over.", ["Join them"]],
				["Someone grabs your purse.", ["Chase", "Let go", "Call the guard (none around)"]],
				["A troll blocks the way.", ["Pass (no gold)"]],
			]
		)
	)


func test_cards_past_the_hand_size_count_as_skipped() -> void:
	_ui.deal(["city"])
	assert_int(_engine.node_service.get_skip_count("well")).is_equal(1)


func test_fewer_eligible_storylets_than_the_hand_size() -> void:
	_ui.hand_size = 10
	_ui.deal(["city"])
	assert_int(_cards().size()).is_equal(4)


func test_a_hand_from_several_pools() -> void:
	_ui.hand_size = 5
	_ui.deal(["city", "night"])
	assert_int(_cards().size()).is_equal(5)


func test_an_empty_pool_emits_hand_empty_and_hides() -> void:
	_ui.deal(["city"])
	_ui.deal(["empty"])
	assert_array(_events).contains(["hand_empty"])
	assert_bool(_ui.visible).is_false()
	assert_array(_cards()).is_empty()


func test_commands_are_emitted() -> void:
	_ui.deal(["city"])
	assert_array(_events).is_equal(['command:header ["Market"]'])


func test_every_card_is_chosen_through_its_option_buttons() -> void:
	_ui.deal(["city"])
	for card: WeavlyCard in _cards():
		assert_int(card.focus_mode).is_equal(Control.FOCUS_NONE)
	var join: Button = _button(_cards()[0], "Join them")
	assert_int(join.focus_mode).is_equal(Control.FOCUS_ALL)
	join.pressed.emit()
	assert_array(_outcome()).is_equal(["You win 5 gold at cards."])
	assert_float(_engine.variable_service.get_variable("gold")).is_equal(5.0)
	assert_bool(_ui.get_node("%Continue").visible).is_true()
	assert_array(_cards()).is_empty()


func test_an_outcome_with_options_hides_continue() -> void:
	_ui.deal(["city"])
	_button(_cards()[1], "Chase").pressed.emit()
	assert_array(_outcome()).is_equal(["You catch the thief.", ["Keep running"]])
	assert_bool(_ui.get_node("%Continue").visible).is_false()
	_button(_cards("%Outcome")[0], "Keep running").pressed.emit()
	assert_array(_outcome()).is_equal(["You're out of breath."])
	assert_bool(_ui.get_node("%Continue").visible).is_true()


func test_a_card_of_only_hints_cant_be_chosen() -> void:
	_ui.deal(["city"])
	var hint: Button = _button(_cards()[2], "Pass (no gold)")
	assert_bool(hint.disabled).is_true()
	assert_int(hint.focus_mode).is_equal(Control.FOCUS_NONE)


func test_continue_deals_again_from_the_same_pools() -> void:
	_ui.deal(["city"])
	_button(_cards()[0], "Join them").pressed.emit()
	_ui.get_node("%Continue").pressed.emit()
	assert_int(_cards().size()).is_equal(3)
	assert_bool(_ui.get_node("%Outcome").visible).is_false()


func test_hovering_selects_an_option_until_the_mouse_leaves() -> void:
	_ui.deal(["city"])
	var join: Button = _button(_cards()[0], "Join them")
	join.mouse_entered.emit()
	assert_bool(join.has_focus()).is_true()
	join.mouse_exited.emit()
	assert_bool(join.has_focus()).is_false()


func test_hovering_continue_selects_it_until_the_mouse_leaves() -> void:
	_ui.deal(["city"])
	_button(_cards()[0], "Join them").pressed.emit()
	var next: Button = _ui.get_node("%Continue")
	next.mouse_entered.emit()
	assert_bool(next.has_focus()).is_true()
	next.mouse_exited.emit()
	assert_bool(next.has_focus()).is_false()


func test_keys_select_and_choose_an_option() -> void:
	_ui.deal(["city"])
	await get_tree().process_frame
	_press_key(KEY_RIGHT)
	assert_bool(_button(_cards()[0], "Join them").has_focus()).is_true()
	_press_key(KEY_ENTER)
	assert_array(_outcome()).is_equal(["You win 5 gold at cards."])


func test_cards_keep_their_width_with_long_options() -> void:
	_ui.deal(["city"])
	await get_tree().process_frame
	for card: WeavlyCard in _cards():
		assert_float(card.size.x).is_equal(_ui.card_size.x)


func test_keys_move_from_a_card_to_the_next_cards_options() -> void:
	_ui.deal(["city"])
	await get_tree().process_frame
	_press_key(KEY_RIGHT)
	_press_key(KEY_RIGHT)
	assert_bool(_cards()[1].is_ancestor_of(get_viewport().gui_get_focus_owner())).is_true()


func test_refuses_while_a_dialogue_runs() -> void:
	_engine.start("inn")
	_ui.deal(["city"])
	assert_bool(_ui.visible).is_false()
	assert_logged([], ["Can't deal cards while a dialogue runs."])


func test_loading_a_state_clears_the_ui() -> void:
	_ui.deal(["city"])
	_engine.reset_state()
	assert_bool(_ui.visible).is_false()
	assert_array(_cards()).is_empty()


func test_disconnecting_the_engine_clears_and_stops_dealing() -> void:
	_ui.deal(["city"])
	_ui.engine = null
	assert_bool(_ui.visible).is_false()
	_ui.deal(["city"])
	assert_array(_cards()).is_empty()
