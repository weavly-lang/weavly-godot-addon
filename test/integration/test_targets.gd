extends WeavlyTestSuite

# Variables as jump, detour, draw, option and node function targets, against the compiler-built
# fixture in targets/src/targets.wvl.

const FIXTURE = "res://test/fixtures/integration/targets/build"

var _engine: WeavlyEngine
var _events: Array[String]


func before_test() -> void:
	_events = []
	_engine = WeavlyEngine.new()
	_engine.dialogue_path = FIXTURE
	add_child(auto_free(_engine))
	_engine.entered_node.connect(func(id: String) -> void: _events.append("enter:" + id))
	_engine.line_reached.connect(
		func(line: WeavlyModel.LineStatement) -> void: _events.append(line.text)
	)
	_engine.finished_dialogue.connect(func() -> void: _events.append("finished"))


func _run(node_id: String) -> void:
	_engine.start(node_id)
	while _engine.is_running() and _engine.get_pending_options().is_empty():
		_engine.next()


func _option_texts() -> Array[String]:
	var texts: Array[String] = []
	for option: WeavlyModel.Option in _engine.get_pending_options():
		texts.append(option.text)
	return texts


func test_a_jump_goes_to_the_node_the_variable_holds() -> void:
	_run("Hall")
	assert_array(_events).is_equal(["enter:Hall", "enter:Cellar", "In the cellar.", "finished"])


func test_a_jump_reads_the_variable_when_it_runs() -> void:
	_run("Rooms")
	assert_array(_events).is_equal(["enter:Rooms", "enter:Attic", "In the attic.", "finished"])


func test_a_detour_returns_from_the_node_the_variable_holds() -> void:
	_run("Aside")
	assert_array(_events).is_equal(["enter:Aside", "enter:Note", "A note.", "Back.", "finished"])


func test_a_draw_takes_from_the_pool_the_variable_holds() -> void:
	_run("Wander")
	assert_array(_events).is_equal(["enter:Wander", "enter:Market", "In the market.", "finished"])


func test_options_offer_the_node_and_pool_the_variables_hold() -> void:
	_run("Choose")
	assert_array(_option_texts()).is_equal(["Attic", "Cellar"])
	assert_logged(
		["targets.wvl:72: error: Can't offer node 'Unlabelled' because it has no label."]
	)


func test_a_pool_option_skips_a_node_without_a_label() -> void:
	_run("ChooseLoose")
	assert_array(_option_texts()).is_equal(["Leave"])
	assert_logged(["Can't offer node 'Loose' because it has no label."])


func test_node_functions_and_meta_reads_take_the_node_the_variable_holds() -> void:
	_engine.count_service.record_visit("Cellar")
	_engine.count_service.set_skip_count("Cellar", 2)
	_run("Count")
	assert_bool(_engine.get_variable("seen")).is_true()
	assert_that(_engine.get_variable("visits")).is_equal(1.0)
	assert_that(_engine.get_variable("skips")).is_equal(2.0)
	assert_that(_engine.get_variable("price")).is_equal(4.0)


func test_meta_that_reads_itself_through_a_variable_is_an_error() -> void:
	assert_object(_engine.get_node_meta("Mirror", "cost")).is_null()
	assert_logged(["Meta key 'cost' of node 'Mirror' reads itself."])
	assert_object(_engine.get_node_meta("Mirror", "cost")).is_null()
	assert_logged(["Meta key 'cost' of node 'Mirror' reads itself."])


func test_a_target_whose_variable_fails_finishes_the_dialogue() -> void:
	_run("Lost")
	assert_array(_events).is_equal(["enter:Lost", "finished"])
	assert_logged(["Variable 'lost' is declared extern but was never defined."])
