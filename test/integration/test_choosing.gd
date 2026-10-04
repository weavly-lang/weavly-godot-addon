extends WeavlyTestSuite

# engine.choose(), can_choose() and the engine's signals for lines, options and variables.

const OPTIONS_FIXTURE = "res://test/fixtures/integration/options/build"
const LINEAR_FIXTURE = "res://test/fixtures/integration/linear/build"

# What the options fixture's open() returns.
var _door_open: bool


func before_test() -> void:
	_door_open = true


func _make_engine(fixture_dir: String) -> WeavlyEngine:
	var engine: WeavlyEngine = WeavlyEngine.new()
	engine.dialogue_path = fixture_dir
	add_child(auto_free(engine))
	if "open" in engine.function_service.get_unregistered():
		engine.register_function("open", func() -> bool: return _door_open)
	return engine


func _door_option(engine: WeavlyEngine, text: String) -> WeavlyModel.Option:
	for option: WeavlyModel.Option in engine.option_service.get_options():
		if option.text.begins_with(text):
			return option
	return null


func test_the_engine_signals_lines_offered_options_and_the_chosen_option() -> void:
	var engine: WeavlyEngine = _make_engine(OPTIONS_FIXTURE)
	var events: Array[String] = []
	engine.line_reached.connect(
		func(line: WeavlyModel.LineStatement) -> void: events.append("line:" + line.text)
	)
	engine.options_offered.connect(
		func(options: Array[WeavlyModel.Option]) -> void:
			events.append("offered:%d" % options.size())
	)
	engine.option_chosen.connect(
		func(option: WeavlyModel.Option) -> void: events.append("chosen:" + option.text)
	)
	engine.start("door")
	assert_bool(engine.choose(_door_option(engine, "Open"))).is_true()
	assert_array(events).is_equal(["offered:3", "chosen:Open", "line:The door opens."])


func test_line_reached_carries_narration_and_character_lines() -> void:
	var engine: WeavlyEngine = _make_engine(LINEAR_FIXTURE)
	var lines: Array[WeavlyModel.LineStatement] = []
	engine.line_reached.connect(func(line: WeavlyModel.LineStatement) -> void: lines.append(line))
	engine.start("start")
	engine.next()
	assert_object(lines[0]).is_instanceof(WeavlyModel.NarrationLine)
	assert_object(lines[1]).is_instanceof(WeavlyModel.CharacterLine)
	assert_str(lines[1].text).is_equal("Hello")


func test_the_engine_forwards_variable_changes() -> void:
	var engine: WeavlyEngine = _make_engine(LINEAR_FIXTURE)
	var changes: Array[Array] = []
	engine.variable_changed.connect(
		func(id: String, value: Variant, old_value: Variant) -> void:
			changes.append([id, value, old_value])
	)
	engine.set_variable("counter", 2.0)
	assert_array(changes).is_equal([["counter", 2.0, 0.0]])


func test_a_refused_choice_returns_false_and_changes_nothing() -> void:
	var engine: WeavlyEngine = _make_engine(OPTIONS_FIXTURE)
	var chosen: Array[WeavlyModel.Option] = []
	engine.option_chosen.connect(func(option: WeavlyModel.Option) -> void: chosen.append(option))
	engine.start("door")
	var option: WeavlyModel.Option = _door_option(engine, "Open")
	_door_open = false
	assert_bool(engine.choose(option)).is_false()
	assert_logged([], ["Can't choose option 'Open' because it's locked."])
	assert_array(chosen).is_empty()
	assert_bool(engine.option_service.has_options()).is_true()
	assert_bool(engine.is_running()).is_true()
	assert_bool(option.is_choosable()).is_false()


func test_can_choose_checks_again_without_a_warning() -> void:
	var engine: WeavlyEngine = _make_engine(OPTIONS_FIXTURE)
	engine.start("door")
	var option: WeavlyModel.Option = _door_option(engine, "Open")
	assert_bool(engine.can_choose(option)).is_true()
	_door_open = false
	assert_bool(engine.can_choose(option)).is_false()
	assert_bool(engine.option_service.has_options()).is_true()


func test_checking_a_choice_leaves_the_random_number_generator_as_it_was() -> void:
	var engine: WeavlyEngine = _make_engine(OPTIONS_FIXTURE)
	engine.start("door")
	var state: int = engine.rng.state
	engine.can_choose(_door_option(engine, "Roll"))
	assert_int(engine.rng.state).is_equal(state)
