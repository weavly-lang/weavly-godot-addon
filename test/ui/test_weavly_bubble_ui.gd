# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# The speech bubble UI against the compiler-built fixture in bubble/src/bubble.wvl.

const FIXTURE = "res://test/fixtures/ui/bubble"
const SCENE = preload("res://addons/weavly/ui/bubble/weavly_bubble_ui.tscn")

var _engine: WeavlyEngine
var _ui: WeavlyBubbleUI
# What the fixture's open() returns.
var _door_open: bool
var _guard: Node2D
# The headless root viewport is tiny, so the world and the UI get one of a usual size.
var _world: SubViewport


func before_test() -> void:
	_engine = WeavlyEngine.new()
	_engine.dialogue_path = FIXTURE + "/build"
	_engine.character_path = FIXTURE + "/characters"
	add_child(auto_free(_engine))
	_door_open = true
	_engine.register_function("open", func() -> bool: return _door_open)
	_world = auto_free(SubViewport.new())
	_world.size = Vector2i(1280, 720)
	add_child(_world)
	_guard = _add_speaker_2d(_world, "guard", Vector2(400, 300))
	_ui = auto_free(SCENE.instantiate())
	_ui.engine = _engine
	_world.add_child(_ui)


func after_test() -> void:
	await get_tree().process_frame


func _add_speaker_2d(parent: Node, character: String, position: Vector2) -> Node2D:
	var body: Node2D = auto_free(Node2D.new())
	body.position = position
	var speaker: WeavlySpeaker = WeavlySpeaker.new()
	speaker.character = character
	body.add_child(speaker)
	parent.add_child(body)
	return body


func _add_speaker_3d(character: String, position: Vector3) -> Node3D:
	var camera: Camera3D = auto_free(Camera3D.new())
	_world.add_child(camera)
	camera.make_current()
	var body: Node3D = auto_free(Node3D.new())
	var speaker: WeavlySpeaker = WeavlySpeaker.new()
	speaker.character = character
	body.add_child(speaker)
	_world.add_child(body)
	body.global_position = position
	return body


func _bubble() -> PanelContainer:
	return _ui.get_node("%Bubble")


func _bubble_text() -> String:
	return (_ui.get_node("%BubbleText") as RichTextLabel).get_parsed_text()


func _bar() -> PanelContainer:
	return _ui.get_node("%Bar")


func _bar_text() -> RichTextLabel:
	return _ui.get_node("%BarText")


func _nameplate() -> Label:
	return _ui.get_node("%Nameplate")


func _choices() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _ui.get_node("%Choices").get_children():
		buttons.append(child)
	return buttons


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	_ui._unhandled_input(event)


func _assert_points_at(point: Vector2) -> void:
	var rect: Rect2 = _bubble().get_rect()
	assert_bool(_bubble().visible).is_true()
	assert_vector(_ui._tail_tip).is_equal_approx(point, Vector2(0.01, 0.01))
	assert_float(rect.get_center().x).is_equal_approx(point.x, 0.01)
	assert_float(rect.end.y).is_equal_approx(point.y - _ui.tail_size.y, 0.01)


func test_hidden_until_a_line_shows() -> void:
	assert_bool(_ui.visible).is_false()
	_engine.start("start")
	assert_bool(_ui.visible).is_true()


func test_speaker_line_shows_in_a_bubble_above_the_2d_speaker() -> void:
	_engine.start("start")
	assert_str(_bubble_text()).is_equal("Halt! Who goes there?")
	assert_bool(_bar().visible).is_false()
	_assert_points_at(Vector2(400, 236))


func test_bubble_follows_the_2d_speaker() -> void:
	_engine.start("start")
	_guard.position = Vector2(600, 400)
	_ui._process(0.0)
	_assert_points_at(Vector2(600, 336))


func test_2d_speaker_goes_through_its_canvas_transform() -> void:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	layer.offset = Vector2(100, 50)
	layer.scale = Vector2(2, 2)
	_world.add_child(layer)
	_add_speaker_2d(layer, "merchant", Vector2(100, 150))
	_engine.start("start")
	_ui.advance()
	_ui.advance()
	assert_str(_bubble_text()).is_equal("Fresh bread!")
	_assert_points_at(Vector2(300, 222))


func test_bubble_above_the_3d_speaker_follows_it() -> void:
	var body: Node3D = _add_speaker_3d("merchant", Vector3(0, 0, -6))
	var camera: Camera3D = _world.get_camera_3d()
	_engine.start("start")
	_ui.advance()
	_ui.advance()
	_assert_points_at(camera.unproject_position(Vector3(0, 2, -6)))
	body.global_position = Vector3(1, 0, -6)
	_ui._process(0.0)
	_assert_points_at(camera.unproject_position(Vector3(1, 2, -6)))


func test_bubble_hides_while_the_3d_speaker_is_behind_the_camera() -> void:
	var body: Node3D = _add_speaker_3d("merchant", Vector3(0, 0, 6))
	_engine.start("start")
	_ui.advance()
	_ui.advance()
	assert_str(_bubble_text()).is_equal("Fresh bread!")
	assert_bool(_bubble().visible).is_false()
	body.global_position = Vector3(0, 0, -6)
	_ui._process(0.0)
	assert_bool(_bubble().visible).is_true()


func test_bubble_hides_while_the_speaker_is_hidden() -> void:
	_engine.start("start")
	_guard.visible = false
	_ui._process(0.0)
	assert_bool(_bubble().visible).is_false()


func test_bubble_stays_inside_the_ui_near_an_edge() -> void:
	_guard.position = Vector2(2, 2)
	_engine.start("start")
	var rect: Rect2 = _bubble().get_rect()
	assert_float(rect.position.x).is_equal(_ui.screen_margin)
	assert_float(rect.position.y).is_equal(_ui.screen_margin)


func test_speaker_leaving_mid_line_hands_the_line_to_the_bar() -> void:
	_engine.start("start")
	_guard.free()
	_ui._process(0.0)
	assert_bool(_bubble().visible).is_false()
	assert_bool(_bar().visible).is_true()
	assert_str(_nameplate().text).is_equal("Guard")
	assert_str(_bar_text().get_parsed_text()).is_equal("Halt! Who goes there?")


func test_narration_shows_in_the_bar_without_a_name() -> void:
	_engine.start("start")
	_ui.advance()
	assert_bool(_bubble().visible).is_false()
	assert_bool(_bar().visible).is_true()
	assert_bool(_nameplate().visible).is_false()
	assert_str(_bar_text().get_parsed_text()).is_equal("The gate creaks.")


func test_character_without_a_speaker_shows_in_the_bar_with_its_name() -> void:
	_engine.start("start")
	_ui.advance()
	_ui.advance()
	assert_bool(_bubble().visible).is_false()
	assert_bool(_nameplate().visible).is_true()
	assert_str(_nameplate().text).is_equal("Merchant")
	assert_str(_bar_text().get_parsed_text()).is_equal("Fresh bread!")


func test_speaker_without_a_character_shows_the_name_as_written() -> void:
	_engine.start("start")
	_ui.advance()
	_ui.advance()
	_ui.advance()
	assert_str(_nameplate().text).is_equal("stranger")


func test_options_show_in_the_bar() -> void:
	_engine.start("start")
	for i: int in 4:
		_ui.advance()
	var buttons: Array[Button] = _choices()
	(
		assert_array(buttons.map(func(button: Button) -> String: return button.text))
		. is_equal(["Answer"])
	)
	assert_bool(_bar().visible).is_true()
	assert_str(_bar_text().get_parsed_text()).is_equal("Psst.")


func test_advancing_doesnt_skip_a_choice() -> void:
	_engine.start("start")
	for i: int in 5:
		_ui.advance()
	assert_int(_choices().size()).is_equal(1)


func test_choosing_an_option_continues() -> void:
	_engine.start("start")
	for i: int in 4:
		_ui.advance()
	_choices()[0].pressed.emit()
	assert_array(_choices()).is_empty()
	assert_bool(_bar().visible).is_false()
	assert_str(_bubble_text()).is_equal("Pass, then.")


func test_navigating_focuses_the_first_option() -> void:
	_engine.start("start")
	for i: int in 4:
		_ui.advance()
	_press(&"ui_down")
	assert_bool(_choices()[0].has_focus()).is_true()


func test_clicking_the_bubble_advances() -> void:
	_engine.start("start")
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_bubble().gui_input.emit(event)
	assert_str(_bar_text().get_parsed_text()).is_equal("The gate creaks.")


func test_clicking_the_bar_advances() -> void:
	_engine.start("start")
	_ui.advance()
	_bar().gui_input.emit(mouse_button(MOUSE_BUTTON_LEFT))
	assert_str(_bar_text().get_parsed_text()).is_equal("Fresh bread!")


func test_only_pressing_the_left_button_advances() -> void:
	_engine.start("start")
	_bubble().gui_input.emit(mouse_button(MOUSE_BUTTON_RIGHT))
	_bubble().gui_input.emit(mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_str(_bubble_text()).is_equal("Halt! Who goes there?")


func test_clicks_and_keys_the_ui_uses_dont_reach_the_game() -> void:
	_engine.start("start")
	var click: Callable = func(event: InputEvent) -> void: _bubble().gui_input.emit(event)
	assert_bool(handles_input(click, mouse_button(MOUSE_BUTTON_LEFT), _world)).is_true()
	(
		assert_bool(handles_input(_ui._unhandled_input, action_pressed(&"ui_accept"), _world))
		. is_true()
	)
	_ui.advance()
	_ui.advance()
	assert_bool(handles_input(_ui._unhandled_input, action_pressed(&"ui_down"), _world)).is_true()


func test_input_action_advances() -> void:
	_engine.start("start")
	_press(&"ui_accept")
	assert_str(_bar_text().get_parsed_text()).is_equal("The gate creaks.")


func test_waits_for_the_player_by_default() -> void:
	_engine.start("bark")
	_ui._process(60.0)
	assert_str(_bubble_text()).is_equal("Move along.")


func test_auto_advance_continues_on_its_own() -> void:
	_ui.auto_advance = 2.0
	_engine.start("bark")
	_ui._process(1.5)
	assert_str(_bubble_text()).is_equal("Move along.")
	_ui._process(1.0)
	assert_str(_bubble_text()).is_equal("I said move along.")
	_ui._process(2.5)
	assert_bool(_engine.is_running()).is_false()
	assert_bool(_ui.visible).is_false()


func test_auto_advance_waits_for_a_choice() -> void:
	_ui.auto_advance = 1.0
	_engine.start("start")
	for i: int in 4:
		_ui.advance()
	_ui._process(5.0)
	assert_int(_choices().size()).is_equal(1)


func test_bbcode_is_shown_as_written_in_lines_and_options() -> void:
	_engine.start("formatted")
	assert_str(_bubble_text()).is_equal("Hello [b]world[/b].")
	_ui.advance()
	assert_str(_choices()[0].text).is_equal("[i]Wave[/i]")


func test_hidden_after_the_dialogue_finishes() -> void:
	_engine.start("answered")
	_ui.advance()
	assert_bool(_engine.is_running()).is_false()
	assert_bool(_ui.visible).is_false()


func test_loading_a_state_clears_the_ui() -> void:
	_engine.start("start")
	_engine.reset_state()
	assert_bool(_ui.visible).is_false()
	assert_bool(_bubble().visible).is_false()


func test_disconnecting_the_engine_hides_and_stops_listening() -> void:
	_engine.start("start")
	_ui.engine = null
	assert_bool(_ui.visible).is_false()
	_engine.next()
	assert_bool(_ui.visible).is_false()


func test_a_refused_choice_keeps_the_choices_and_shows_the_change() -> void:
	_engine.start("door")
	_door_open = false
	_choices()[0].pressed.emit()
	assert_logged([], ["Can't choose option 'Open' because it's locked."])
	assert_bool(_choices()[0].visible).is_false()
	assert_bool(_choices()[1].visible).is_true()
	_choices()[1].pressed.emit()
	assert_str(_engine.current_node_id).is_equal("answered")
