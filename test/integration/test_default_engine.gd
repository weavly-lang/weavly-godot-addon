extends GutTest

# End-to-end tests for WeavlyDefaultEngine. Loads fixture JSON dialogs, drives the
# real compiler -> executor -> service pipeline, and asserts on signals and
# final variable state.


const LINEAR_FIXTURE = "res://test/fixtures/integration/linear"
const CI_SMOKE_FIXTURE = "res://test/fixtures/integration/ci_smoke"

# =====================
# Setup helpers
# =====================

var _signal_log: Array[String]


func before_each() -> void:
	_signal_log = []


# Build a WeavlyDefaultEngine pointed at a fixture dir. All asset paths point at the
# same dir; non-dialog asset lookups simply find no matching extensions, which
# avoids needing an extra empty fixture dir on disk. The @export paths are set
# before add_child so they are in place when _ready runs.
func _make_engine(fixture_dir: String) -> Node:
	var engine = WeavlyDefaultEngine.new()
	engine.dialog_path = fixture_dir
	engine.video_path = fixture_dir
	engine.image_path = fixture_dir
	engine.character_path = fixture_dir
	engine.variable_path = fixture_dir
	add_child_autofree(engine)
	_connect_signal_log(engine)
	return engine


func _connect_signal_log(engine: WeavlyEngine) -> void:
	engine.started_dialog.connect(func() -> void: _signal_log.append("started_dialog"))
	engine.entered_node.connect(
		func(node_id: StringName) -> void: _signal_log.append("entered_node:%s" % node_id)
	)
	engine.finished_dialog.connect(func() -> void: _signal_log.append("finished_dialog"))


# =====================
# start()
# =====================


func test_start_on_idle_emits_started_dialog_and_enters_first_node() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	assert_eq(_signal_log[0], "started_dialog")
	assert_eq(_signal_log[1], "entered_node:start")


func test_start_on_running_dialog_warns_and_does_nothing() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	var log_after_first_start = _signal_log.duplicate()
	engine.start("start")
	# Second start pushes a warning and emits no further signals.
	assert_engine_error(1)
	assert_eq(_signal_log, log_after_first_start)


# =====================
# enter_node()
# =====================


func test_enter_node_marks_node_as_visited_and_emits_entered_node() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	# Pre-condition: visited flag for "start" is initialized to false.
	assert_false(engine.variable_service.get_variable("start"))
	engine.start("start")
	# enter_node was invoked by start; assert the flag is now true and that the
	# entered_node signal carried the expected id.
	assert_true(engine.variable_service.get_variable("start"))
	assert_true(_signal_log.has("entered_node:start"))


func test_enter_node_with_unknown_id_pushes_error_and_finishes() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	var log_before = _signal_log.size()
	engine.enter_node("does_not_exist")
	# Unknown id pushes an error (from node_service.get_node and from the engine
	# itself) and then calls finish, which emits finished_dialog.
	assert_push_error(2)
	assert_eq(_signal_log[log_before], "finished_dialog")


# =====================
# finish()
# =====================


func test_finish_emits_finished_dialog_and_allows_restart() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	engine.finish()
	assert_eq(_signal_log.back(), "finished_dialog")
	var log_after_finish = _signal_log.duplicate()
	# After finish, start should be allowed again and emit started_dialog.
	engine.start("start")
	assert_eq(_signal_log.size(), log_after_finish.size() + 2)
	assert_eq(_signal_log[log_after_finish.size()], "started_dialog")


# =====================
# Full linear run
# =====================


func test_full_linear_dialog_run_signals_and_final_state() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	# start node body: narration, character, set, goto
	# Narration pauses, so drive forward with next() until the dialog finishes.
	engine.next()  # character line -> pause
	engine.next()  # set counter, goto end, narration "Goodbye" -> pause
	engine.next()  # finish

	var expected_signals: Array[String] = [
		"started_dialog",
		"entered_node:start",
		"entered_node:end",
		"finished_dialog",
	]
	assert_eq(_signal_log, expected_signals)

	# Variables: counter set by the dialog, visited flags for both nodes set.
	assert_eq(engine.variable_service.get_variable("counter"), 7.0)
	assert_true(engine.variable_service.get_variable("start"))
	assert_true(engine.variable_service.get_variable("end"))


# =====================
# CI-smoke fixture
# =====================


# The compiler repo ships a smoke-test dialog covering narration, character,
# set, match, option, random, goto, and finish. Running it here verifies the
# addon stays in sync with the compiler's emitted JSON shape.
func test_ci_smoke_fixture_runs_to_completion_via_random_path() -> void:
	var engine = _make_engine(CI_SMOKE_FIXTURE)
	engine.start("start")
	# start node: narration pauses immediately. Drive past the character line,
	# the chain of set/match statements (which goto choices), the character
	# line at choices, and finally land on the option block.
	engine.next()  # character "Let the test begin." -> pause
	engine.next()  # sets + match (-> goto choices) + character "Which path?" -> pause
	engine.next()  # option block -> options registered, loop exits

	# We should now be sitting on the options at choices.
	assert_true(engine.option_service.has_options())
	var options: Array = engine.option_service.pending_options
	# has_key was set to false, so only "Roll the dice" should pass the filter.
	assert_eq(options.size(), 1)
	assert_eq(options[0].text, "Roll the dice")

	# Choosing the dice option drives us through random_node -> match_node ->
	# narration ("No key needed.", which pauses) -> goto end -> finish.
	engine.option_service.choose_option(options[0])
	engine.next()  # past the narration, into end's FinishStatement

	# Final state: dialog finished, all visited flags set, has_key was toggled
	# to false by the last set statement.
	assert_eq(_signal_log.back(), "finished_dialog")
	assert_true(engine.variable_service.get_variable("start"))
	assert_true(engine.variable_service.get_variable("choices"))
	assert_true(engine.variable_service.get_variable("random_node"))
	assert_true(engine.variable_service.get_variable("match_node"))
	assert_true(engine.variable_service.get_variable("end"))
	assert_eq(engine.variable_service.get_variable("score"), 13.0)
	assert_false(engine.variable_service.get_variable("has_key"))
