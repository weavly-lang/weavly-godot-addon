extends WeavlyTestSuite

# End-to-end tests for WeavlyDefaultEngine. Loads fixture JSON dialogs, drives the
# real compiler -> executor -> service pipeline, and asserts on signals and
# final variable state.

const LINEAR_FIXTURE = "res://test/fixtures/integration/linear"
const CI_SMOKE_FIXTURE = "res://test/fixtures/integration/ci_smoke"
const GOTO_CYCLE_FIXTURE = "res://test/fixtures/integration/goto_cycle"
const LIST_INTERLEAVE_FIXTURE = "res://test/fixtures/integration/list_interleave"
const BOUNDED_LOOP_FIXTURE = "res://test/fixtures/integration/bounded_loop"

const IMPL_PATH = "res://addons/weavly/src/services/implementations/"

# =====================
# Setup helpers
# =====================

var _signal_log: Array[String]
var _narration_log: Array[String]
var _options_added_count: int


func before_test() -> void:
	_signal_log = []
	_narration_log = []
	_options_added_count = 0


# Build a WeavlyDefaultEngine pointed at a fixture dir. All asset paths point at the
# same dir; non-dialog asset lookups simply find no matching extensions, which
# avoids needing an extra empty fixture dir on disk. The @export paths are set
# before add_child so they are in place when _ready runs.
func _make_engine(fixture_dir: String) -> Node:
	var engine = _new_engine(fixture_dir)
	add_child(auto_free(engine))
	_connect_signal_log(engine)
	return engine


# Same as _make_engine but wires the list_* service variants, which stream
# narration and options in one pass instead of pausing (Twine-style overviews).
func _make_list_engine(fixture_dir: String) -> Node:
	var engine = _new_engine(fixture_dir)
	engine.statement_service_script = load(IMPL_PATH + "list_statement_service.gd")
	engine.option_service_script = load(IMPL_PATH + "list_option_service.gd")
	engine.line_service_script = load(IMPL_PATH + "list_line_service.gd")
	engine.command_service_script = load(IMPL_PATH + "list_command_service.gd")
	add_child(auto_free(engine))
	_connect_signal_log(engine)
	return engine


func _new_engine(fixture_dir: String) -> WeavlyDefaultEngine:
	var engine = WeavlyDefaultEngine.new()
	engine.dialog_path = fixture_dir
	engine.video_path = fixture_dir
	engine.image_path = fixture_dir
	engine.character_path = fixture_dir
	engine.variable_path = fixture_dir
	return engine


func _connect_signal_log(engine: WeavlyEngine) -> void:
	engine.started_dialog.connect(func() -> void: _signal_log.append("started_dialog"))
	engine.entered_node.connect(
		func(node_id: StringName) -> void: _signal_log.append("entered_node:%s" % node_id)
	)
	engine.finished_dialog.connect(func() -> void: _signal_log.append("finished_dialog"))


# Records narration text and counts option registrations, used to assert that
# list mode streams both in a single pass.
func _connect_content_log(engine: WeavlyEngine) -> void:
	engine.line_service.executed_narration_line.connect(
		func(line: WeavlyModel.NarrationLine) -> void: _narration_log.append(line.text)
	)
	engine.option_service.options_added.connect(
		func(_options: Array[WeavlyModel.Option]) -> void: _options_added_count += 1
	)


# =====================
# start()
# =====================


func test_start_on_idle_emits_started_dialog_and_enters_first_node() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	assert_that(_signal_log[0]).is_equal("started_dialog")
	assert_that(_signal_log[1]).is_equal("entered_node:start")


func test_start_on_running_dialog_warns_and_does_nothing() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	var log_after_first_start = _signal_log.duplicate()
	engine.start("start")
	# Second start pushes a warning and emits no further signals.
	assert_logged([], ["Dialog is already in progress, cant start for node with ID 'start."])
	assert_that(_signal_log).is_equal(log_after_first_start)


# =====================
# enter_node()
# =====================


func test_enter_node_marks_node_as_visited_and_emits_entered_node() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	# Pre-condition: visited flag for "start" is initialized to false.
	assert_bool(engine.variable_service.get_variable("start")).is_false()
	engine.start("start")
	# enter_node was invoked by start; assert the flag is now true and that the
	# entered_node signal carried the expected id.
	assert_bool(engine.variable_service.get_variable("start")).is_true()
	assert_bool(_signal_log.has("entered_node:start")).is_true()


func test_enter_node_with_unknown_id_pushes_error_and_finishes() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	var log_before = _signal_log.size()
	engine.enter_node("does_not_exist")
	# Unknown id pushes an error (from node_service.get_node and from the engine
	# itself) and then calls finish, which emits finished_dialog.
	assert_logged(
		[
			"Node with id 'does_not_exist' doesn't exist",
			"Can't enter node with ID 'does_not_exist' because it's null, finsishing the dialog."
		]
	)
	assert_that(_signal_log[log_before]).is_equal("finished_dialog")


# =====================
# finish()
# =====================


func test_finish_emits_finished_dialog_and_allows_restart() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	engine.finish()
	assert_that(_signal_log.back()).is_equal("finished_dialog")
	var log_after_finish = _signal_log.duplicate()
	# After finish, start should be allowed again and emit started_dialog.
	engine.start("start")
	assert_that(_signal_log.size()).is_equal(log_after_finish.size() + 2)
	assert_that(_signal_log[log_after_finish.size()]).is_equal("started_dialog")


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
	assert_that(_signal_log).is_equal(expected_signals)

	# Variables: counter set by the dialog, visited flags for both nodes set.
	assert_that(engine.variable_service.get_variable("counter")).is_equal(7.0)
	assert_bool(engine.variable_service.get_variable("start")).is_true()
	assert_bool(engine.variable_service.get_variable("end")).is_true()


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
	assert_bool(engine.option_service.has_options()).is_true()
	var options: Array = engine.option_service.pending_options
	# has_key was set to false, so only "Roll the dice" should pass the filter.
	assert_that(options.size()).is_equal(1)
	assert_that(options[0].text).is_equal("Roll the dice")

	# Choosing the dice option drives us through random_node -> match_node ->
	# narration ("No key needed.", which pauses) -> goto end -> finish.
	engine.option_service.choose_option(options[0])
	engine.next()  # past the narration, into end's FinishStatement

	# Final state: dialog finished, all visited flags set, has_key was toggled
	# to false by the last set statement.
	assert_that(_signal_log.back()).is_equal("finished_dialog")
	assert_bool(engine.variable_service.get_variable("start")).is_true()
	assert_bool(engine.variable_service.get_variable("choices")).is_true()
	assert_bool(engine.variable_service.get_variable("random_node")).is_true()
	assert_bool(engine.variable_service.get_variable("match_node")).is_true()
	assert_bool(engine.variable_service.get_variable("end")).is_true()
	assert_that(engine.variable_service.get_variable("score")).is_equal(13.0)
	assert_bool(engine.variable_service.get_variable("has_key")).is_false()


# =====================
# Goto cycles (issue #39)
# =====================


func test_self_referencing_goto_aborts_via_error_not_crash() -> void:
	var engine = _make_engine(GOTO_CYCLE_FIXTURE)
	# A node that gotos itself never pauses. Pre-fix this recursed until stack
	# overflow; now the flat loop trips the guard and finishes cleanly.
	engine.max_node_entries_per_step = 5
	engine.start("self_loop")
	assert_logged(["Entered 5 nodes without pausing (likely a goto cycle); finishing the dialog."])
	assert_that(_signal_log.back()).is_equal("finished_dialog")
	assert_bool(engine.is_running()).is_false()


func test_two_node_goto_cycle_aborts_via_error() -> void:
	var engine = _make_engine(GOTO_CYCLE_FIXTURE)
	# Indirect cycle (ping -> pong -> ping) is caught the same way as a self-loop.
	engine.max_node_entries_per_step = 5
	engine.start("ping")
	assert_logged(["Entered 5 nodes without pausing (likely a goto cycle); finishing the dialog."])
	assert_that(_signal_log.back()).is_equal("finished_dialog")
	assert_bool(engine.is_running()).is_false()


func test_bounded_goto_loop_completes_without_tripping_guard() -> void:
	var engine = _make_engine(BOUNDED_LOOP_FIXTURE)
	# countdown decrements i from 3 and gotos itself while i > 0, re-entering the
	# same node three times before finishing. The counter guard allows this; a
	# naive "node revisited" detector would wrongly abort it.
	engine.start("countdown")
	assert_that(_signal_log.back()).is_equal("finished_dialog")
	assert_that(engine.variable_service.get_variable("i")).is_equal(0.0)
	(
		assert_that(_signal_log.count("entered_node:countdown"))
		. override_failure_message("node should be entered exactly three times")
		. is_equal(3)
	)


# =====================
# List mode streaming
# =====================


func test_list_mode_streams_interleaved_narration_and_options_in_one_pass() -> void:
	var engine = _make_list_engine(LIST_INTERLEAVE_FIXTURE)
	_connect_content_log(engine)
	engine.start("town")
	# List services do not pause on lines or stop on options, so the whole town
	# node streams out in a single start() call and then pauses on the drained
	# stack, waiting for the host to choose.
	assert_that(_narration_log).is_equal(
		["You enter the town square.", "A fountain bubbles nearby."]
	)
	(
		assert_that(_options_added_count)
		. override_failure_message("both option blocks should register in one pass")
		. is_equal(2)
	)
	(
		assert_bool(engine.is_running())
		. override_failure_message("list mode pauses rather than finishing")
		. is_true()
	)
	assert_bool(engine.statement_service.is_paused()).is_true()
	assert_bool(_signal_log.has("finished_dialog")).is_false()


func test_list_mode_goto_cycle_aborts_via_error() -> void:
	var engine = _make_list_engine(GOTO_CYCLE_FIXTURE)
	# In list mode has_options() never stops the loop, so the entry guard is the
	# only thing that can break a goto cycle.
	engine.max_node_entries_per_step = 5
	engine.start("self_loop")
	assert_logged(["Entered 5 nodes without pausing (likely a goto cycle); finishing the dialog."])
	assert_that(_signal_log.back()).is_equal("finished_dialog")
	assert_bool(engine.is_running()).is_false()
