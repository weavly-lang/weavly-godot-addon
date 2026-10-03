# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# The location stack against the compiler-built fixture in detours/src/detours.wvl.

const FIXTURE = "res://test/fixtures/integration/detours/build"

var _engine: WeavlyDefaultEngine
var _events: Array[String]


func before_test() -> void:
	_events = []
	_engine = WeavlyDefaultEngine.new()
	_engine.dialogue_path = FIXTURE
	_engine.video_path = FIXTURE
	_engine.image_path = FIXTURE
	_engine.character_path = FIXTURE
	add_child(auto_free(_engine))
	_engine.entered_node.connect(func(id: String) -> void: _events.append("enter:" + id))
	_engine.left_node.connect(func(id: String) -> void: _events.append("leave:" + id))
	_engine.line_service.executed_narration_line.connect(
		func(line: WeavlyModel.NarrationLine) -> void: _events.append(line.text)
	)
	_engine.finished_dialogue.connect(func() -> void: _events.append("finished"))


func _run(node_id: String) -> void:
	_engine.start(node_id)
	while _engine.is_running():
		_engine.next()


func _visits(ids: Array[String]) -> Array[int]:
	var counts: Array[int] = []
	for id: String in ids:
		counts.append(_engine.node_service.get_visit_count(id))
	return counts


func test_a_detour_runs_the_node_and_continues_after_it() -> void:
	_run("travel")
	(
		assert_array(_events)
		. is_equal(
			[
				"enter:travel",
				"You set off.",
				"enter:ambush",
				"Bandits!",
				"leave:ambush",
				"You arrive.",
				"leave:travel",
				"finished",
			]
		)
	)
	assert_array(_visits(["travel", "ambush"])).is_equal([1, 1])


func test_the_detoured_node_is_on_top_of_the_location_stack() -> void:
	_engine.start("travel")
	_engine.next()
	assert_array(_engine.get_location_stack()).is_equal(["travel", "ambush"])
	assert_str(_engine.current_node_id).is_equal("ambush")
	assert_int(_engine.current_line).is_equal(8)
	_engine.next()
	assert_array(_engine.get_location_stack()).is_equal(["travel"])
	assert_int(_engine.current_line).is_equal(4)


func test_nested_detours_return_in_order() -> void:
	_run("nested")
	(
		assert_array(_events.filter(func(event: String) -> bool: return ":" not in event))
		. is_equal(["In inner.", "Back in middle.", "Back in nested.", "finished"])
	)
	(
		assert_array(_events.filter(func(event: String) -> bool: return "leave:" in event))
		. is_equal(["leave:inner", "leave:middle", "leave:nested"])
	)


func test_a_jump_inside_a_detour_leaves_every_running_node() -> void:
	_run("escape")
	(
		assert_array(_events)
		. is_equal(
			[
				"enter:escape",
				"enter:runaway",
				"leave:runaway",
				"leave:escape",
				"enter:safe",
				"Safe.",
				"leave:safe",
				"finished",
			]
		)
	)
	assert_array(_visits(["escape", "runaway", "safe"])).is_equal([1, 1, 1])


func test_finish_inside_a_detour_ends_the_dialogue() -> void:
	_run("quit")
	assert_array(_events).is_equal(
		["enter:quit", "enter:stop", "leave:stop", "leave:quit", "finished"]
	)
	assert_array(_visits(["quit", "stop"])).is_equal([1, 1])


func test_finishing_from_the_game_leaves_every_running_node() -> void:
	_engine.start("travel")
	_engine.next()
	_engine.finish()
	(
		assert_array(_events)
		. is_equal(
			[
				"enter:travel",
				"You set off.",
				"enter:ambush",
				"Bandits!",
				"leave:ambush",
				"leave:travel",
				"finished",
			]
		)
	)
	assert_array(_visits(["travel", "ambush"])).is_equal([1, 1])
	assert_array(_engine.get_location_stack()).is_empty()


func test_finishing_from_a_left_node_handler_finishes_once() -> void:
	_engine.left_node.connect(func(_id: String) -> void: _engine.finish())
	_engine.start("travel")
	_engine.next()
	_engine.finish()
	(
		assert_array(_events.filter(func(event: String) -> bool: return event == "finished"))
		. has_size(1)
	)
	assert_array(_visits(["travel", "ambush"])).is_equal([1, 1])


func test_loading_a_state_while_a_detour_runs_leaves_no_nodes() -> void:
	_engine.start("nested")
	var state: Dictionary = _engine.get_state()
	_engine.next()
	_events.clear()
	_engine.set_state(state)
	assert_array(_events.filter(func(event: String) -> bool: return "leave:" in event)).is_empty()
	assert_array(_visits(["nested", "middle", "inner"])).is_equal([0, 0, 0])


func test_a_node_split_by_a_detour_at_its_end() -> void:
	_run("split_a")
	(
		assert_array(_events)
		. is_equal(
			[
				"enter:split_a",
				"First half.",
				"enter:split_b",
				"Second half.",
				"leave:split_b",
				"leave:split_a",
				"finished",
			]
		)
	)


func test_detouring_past_the_depth_limit_finishes_with_an_error() -> void:
	_engine.max_detour_depth = 3
	_run("loop")
	assert_logged(["Can't detour to node 'loop' past 3 running nodes; finishing the dialogue."])
	assert_str(_events.back()).is_equal("finished")
	assert_array(_engine.get_location_stack()).is_empty()


func test_saving_inside_a_detour_replays_the_outermost_node() -> void:
	_engine.start("travel")
	_engine.next()
	var state: Dictionary = _engine.get_state()
	assert_str(state["node"]).is_equal("travel")
	_engine.finish()
	_events.clear()
	_engine.set_state(state)
	assert_array(_events).is_equal(["enter:travel", "You set off."])
	assert_array(_engine.get_location_stack()).is_equal(["travel"])


func test_render_runs_detours_in_place() -> void:
	var entries: Array[WeavlyModel.Statement] = _engine.render("travel")
	(
		assert_array(entries.map(func(line: WeavlyModel.Statement) -> String: return line.text))
		. is_equal(["You set off.", "Bandits!", "You arrive."])
	)
	assert_array(_visits(["travel", "ambush"])).is_equal([1, 1])


func test_render_option_returns_from_a_detour() -> void:
	var entries: Array[WeavlyModel.Statement] = _engine.render("lookout")
	var look: WeavlyModel.Option = (entries[0] as WeavlyModel.OptionBlock).options[0]
	var outcome: Array[WeavlyModel.Statement] = _engine.render_option(look)
	(
		assert_array(outcome.map(func(line: WeavlyModel.Statement) -> String: return line.text))
		. is_equal(["Bandits!"])
	)
	assert_bool(_engine.is_running()).is_false()
