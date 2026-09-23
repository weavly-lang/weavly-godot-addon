# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# End-to-end tests for WeavlyDefaultEngine. Loads fixture JSON dialogues, drives the
# real compiler -> executor -> service pipeline, and asserts on signals and
# final variable state.

const LINEAR_FIXTURE = "res://test/fixtures/integration/linear"
const CI_SMOKE_FIXTURE = "res://test/fixtures/integration/ci_smoke/build"
const CI_SMOKE_GLOBALS_JSON = CI_SMOKE_FIXTURE + "/globals.wvl.json"
const GOTO_CYCLE_FIXTURE = "res://test/fixtures/integration/goto_cycle"
const LIST_INTERLEAVE_FIXTURE = "res://test/fixtures/integration/list_interleave"
const BOUNDED_LOOP_FIXTURE = "res://test/fixtures/integration/bounded_loop"
const OPTIONS_FIXTURE = "res://test/fixtures/integration/options"
const VISITS_FIXTURE = "res://test/fixtures/integration/visits"
const FUNCTIONS_FIXTURE = "res://test/fixtures/integration/functions"

const IMPL_PATH = "res://addons/weavly/src/services/implementations/"

# =====================
# Setup helpers
# =====================

var _signal_log: Array[String]
var _narration_log: Array[String]
var _command_log: Array[String]
var _options_added_count: int


func before_test() -> void:
	_signal_log = []
	_narration_log = []
	_command_log = []
	_options_added_count = 0


# Build a WeavlyDefaultEngine pointed at a fixture dir. All asset paths point at the
# same dir; non-dialogue asset lookups simply find no matching extensions, which
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
	engine.dialogue_path = fixture_dir
	engine.video_path = fixture_dir
	engine.image_path = fixture_dir
	engine.character_path = fixture_dir
	engine.variable_path = fixture_dir
	return engine


func _connect_signal_log(engine: WeavlyEngine) -> void:
	engine.started_dialogue.connect(func() -> void: _signal_log.append("started_dialogue"))
	engine.entered_node.connect(
		func(node_id: StringName) -> void: _signal_log.append("entered_node:%s" % node_id)
	)
	engine.finished_dialogue.connect(func() -> void: _signal_log.append("finished_dialogue"))
	engine.command_service.executed_command.connect(
		func(command: WeavlyModel.CommandStatement, args: Array) -> void:
			_command_log.append("%s:%s" % [command.id, ",".join(args.map(str))])
	)


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


func test_start_on_idle_emits_started_dialogue_and_enters_first_node() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	assert_that(_signal_log[0]).is_equal("started_dialogue")
	assert_that(_signal_log[1]).is_equal("entered_node:start")


func test_start_on_running_dialogue_warns_and_does_nothing() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	var log_after_first_start = _signal_log.duplicate()
	engine.start("start")
	# Second start pushes a warning and emits no further signals.
	assert_logged([], ["Dialogue is already in progress, can't start for node with ID 'start'."])
	assert_that(_signal_log).is_equal(log_after_first_start)


# =====================
# enter_node()
# =====================


func test_enter_node_emits_entered_node_without_counting_a_visit() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	assert_bool(_signal_log.has("entered_node:start")).is_true()
	assert_int(engine.node_service.get_visit_count("start")).is_equal(0)


func test_start_with_unknown_id_reports_once_and_finishes() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("typo")
	assert_logged(["Can't enter node 'typo' because it doesn't exist, finishing the dialogue."])
	assert_that(_signal_log).is_equal(["started_dialogue", "finished_dialogue"])
	assert_bool(engine.is_running()).is_false()


func test_enter_node_with_unknown_id_reports_once_and_finishes() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	var log_before = _signal_log.size()
	engine.enter_node("does_not_exist")
	assert_logged(
		["Can't enter node 'does_not_exist' because it doesn't exist, finishing the dialogue."]
	)
	assert_that(_signal_log[log_before]).is_equal("finished_dialogue")


# =====================
# finish()
# =====================


func test_finish_emits_finished_dialogue_and_allows_restart() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	engine.finish()
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
	var log_after_finish = _signal_log.duplicate()
	# After finish, start should be allowed again and emit started_dialogue.
	engine.start("start")
	assert_that(_signal_log.size()).is_equal(log_after_finish.size() + 2)
	assert_that(_signal_log[log_after_finish.size()]).is_equal("started_dialogue")


func test_finish_twice_emits_finished_dialogue_once() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	engine.finish()
	engine.finish()
	assert_int(_signal_log.count("finished_dialogue")).is_equal(1)


func test_finish_while_options_are_showing_lets_the_next_start_run() -> void:
	var engine = _make_engine(OPTIONS_FIXTURE)
	engine.start("menu")
	assert_bool(engine.option_service.has_options()).is_true()
	engine.finish()
	assert_bool(engine.option_service.has_options()).is_false()
	engine.start("after")
	var expected_signals: Array[String] = [
		"started_dialogue",
		"entered_node:menu",
		"finished_dialogue",
		"started_dialogue",
		"entered_node:after",
	]
	assert_that(_signal_log).is_equal(expected_signals)
	assert_bool(engine.is_running()).is_true()


func test_choosing_an_option_after_finish_is_ignored() -> void:
	var engine = _make_engine(OPTIONS_FIXTURE)
	engine.start("menu")
	var option: WeavlyModel.Option = engine.option_service.pending_options[0]
	engine.finish()
	var log_after_finish: Array[String] = _signal_log.duplicate()
	engine.option_service.choose_option(option)
	assert_logged([], ["Can't choose option 'Go on' because it isn't offered right now."])
	assert_that(_signal_log).is_equal(log_after_finish)


func test_start_from_finished_dialogue_after_game_calls_finish() -> void:
	var engine = _make_engine(OPTIONS_FIXTURE)
	engine.start("menu")
	engine.finished_dialogue.connect(func() -> void: engine.start("after"), CONNECT_ONE_SHOT)
	engine.finish()
	assert_bool(engine.is_running()).is_true()
	assert_that(_signal_log.slice(-3)).is_equal(
		["finished_dialogue", "started_dialogue", "entered_node:after"]
	)


func test_start_from_finished_dialogue_after_finish_statement() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.finished_dialogue.connect(func() -> void: engine.start("start"), CONNECT_ONE_SHOT)
	engine.start("start")
	engine.next()
	engine.next()
	engine.next()  # end's @finish, whose handler starts "start" again
	assert_bool(engine.is_running()).is_true()
	assert_that(_signal_log.slice(-3)).is_equal(
		["finished_dialogue", "started_dialogue", "entered_node:start"]
	)


func test_double_choose_runs_the_option_once() -> void:
	var engine = _make_engine(OPTIONS_FIXTURE)
	engine.start("menu")
	var option: WeavlyModel.Option = engine.option_service.pending_options[0]
	engine.option_service.choose_option(option)
	engine.option_service.choose_option(option)
	assert_logged([], ["Can't choose option 'Go on' because it isn't offered right now."])
	assert_int(_signal_log.count("entered_node:after")).is_equal(1)


func test_choosing_a_hint_keeps_the_options_showing() -> void:
	var engine = _make_engine(OPTIONS_FIXTURE)
	engine.start("menu")
	var hint: WeavlyModel.Option = engine.option_service.pending_options[1]
	engine.option_service.choose_option(hint)
	assert_logged([], ["Can't choose option 'Locked' because it's a hint."])
	assert_bool(engine.option_service.has_options()).is_true()


# =====================
# Full linear run
# =====================


func test_full_linear_dialogue_run_signals_and_final_state() -> void:
	var engine = _make_engine(LINEAR_FIXTURE)
	engine.start("start")
	# start node body: narration, character, set, goto
	# Narration pauses, so drive forward with next() until the dialogue finishes.
	engine.next()  # character line -> pause
	engine.next()  # set counter, goto end, narration "Goodbye" -> pause
	engine.next()  # finish

	var expected_signals: Array[String] = [
		"started_dialogue",
		"entered_node:start",
		"entered_node:end",
		"finished_dialogue",
	]
	assert_that(_signal_log).is_equal(expected_signals)

	# start is left by its goto, end by its @finish.
	assert_that(engine.variable_service.get_variable("counter")).is_equal(7.0)
	assert_int(engine.node_service.get_visit_count("start")).is_equal(1)
	assert_int(engine.node_service.get_visit_count("end")).is_equal(1)


# =====================
# CI-smoke fixture
# =====================


# Smoke-test dialogue covering every statement type. CI rebuilds build/ from src/ with
# the published compiler, so this also guards the emitted JSON shape.
func test_ci_smoke_fixture_runs_to_completion_via_random_path() -> void:
	var engine = _make_engine(CI_SMOKE_FIXTURE)
	# reputation is declared extern, so the game defines it.
	engine.variable_service.set_variable("reputation", 3.0)
	engine.start("start")
	# start node: narration pauses immediately. Drive past the character line,
	# the chain of set/match statements (which goto choices), the character
	# line at choices, and finally land on the option block.
	engine.next()  # commands, then character "Let the test begin." -> pause
	assert_that(_command_log).is_equal(["fade_in:", "play_sound:chime.ogg"])
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

	# Final state: dialogue finished, every node visited once, has_key was toggled
	# to false by the last set statement, and end read the visits and reputation.
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
	for node_id: String in ["start", "choices", "random_node", "match_node", "end"]:
		assert_int(engine.node_service.get_visit_count(node_id)).is_equal(1)
	assert_that(engine.variable_service.get_variable("choice_visits")).is_equal(1.0)
	assert_bool(engine.variable_service.get_variable("been_to_start")).is_true()
	assert_that(engine.variable_service.get_variable("score")).is_equal(20.0)
	assert_that(_command_log.back()).is_equal("log:3.0,2.0")
	assert_bool(engine.variable_service.get_variable("has_key")).is_false()


# The node-less build artifact is the only trace of the split sources, so it is what
# this asserts: node ids and declarations look identical either way.
func test_declarations_from_a_node_less_file_merge_without_adding_nodes() -> void:
	var hint: String = (
		"globals.wvl.json is gone. Keep the ci_smoke sources split, declarations in "
		+ "globals.wvl and nodes in story.wvl, so the compiler's cross-file "
		+ "declaration merge stays covered."
	)
	var exists: bool = FileAccess.file_exists(CI_SMOKE_GLOBALS_JSON)
	assert_bool(exists).override_failure_message(hint).is_true()
	if not exists:
		return
	var globals: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(CI_SMOKE_GLOBALS_JSON)
	)
	assert_that(globals["nodes"]).is_empty()

	var engine = _make_engine(CI_SMOKE_FIXTURE)
	var ids: Array[String] = []
	for node: WeavlyModel.WeavlyNode in engine.node_service.get_all_nodes():
		ids.append(node.id)
	ids.sort()
	assert_that(ids).is_equal(["choices", "end", "match_node", "random_node", "start"])
	assert_bool(engine.variable_service.has("score")).is_true()
	assert_bool(engine.variable_service.has("player_name")).is_true()
	assert_bool(engine.variable_service.has("has_key")).is_true()
	assert_bool(engine.variable_service.get_declaration("reputation").extern).is_true()


# =====================
# Goto cycles (issue #39)
# =====================


func test_self_referencing_goto_aborts_via_error_not_crash() -> void:
	var engine = _make_engine(GOTO_CYCLE_FIXTURE)
	# A node that gotos itself never pauses. Pre-fix this recursed until stack
	# overflow; now the flat loop trips the guard and finishes cleanly.
	engine.max_node_entries_per_step = 5
	engine.start("self_loop")
	assert_logged(
		["Entered 5 nodes without pausing (likely a goto cycle); finishing the dialogue."]
	)
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
	assert_bool(engine.is_running()).is_false()


func test_two_node_goto_cycle_aborts_via_error() -> void:
	var engine = _make_engine(GOTO_CYCLE_FIXTURE)
	# Indirect cycle (ping -> pong -> ping) is caught the same way as a self-loop.
	engine.max_node_entries_per_step = 5
	engine.start("ping")
	assert_logged(
		["Entered 5 nodes without pausing (likely a goto cycle); finishing the dialogue."]
	)
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
	assert_bool(engine.is_running()).is_false()


func test_bounded_goto_loop_completes_without_tripping_guard() -> void:
	var engine = _make_engine(BOUNDED_LOOP_FIXTURE)
	# countdown decrements i from 3 and gotos itself while i > 0, re-entering the
	# same node three times before finishing. The counter guard allows this; a
	# naive "node revisited" detector would wrongly abort it.
	engine.start("countdown")
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
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
	assert_bool(_signal_log.has("finished_dialogue")).is_false()


func test_list_mode_goto_cycle_aborts_via_error() -> void:
	var engine = _make_list_engine(GOTO_CYCLE_FIXTURE)
	# In list mode has_options() never stops the loop, so the entry guard is the
	# only thing that can break a goto cycle.
	engine.max_node_entries_per_step = 5
	engine.start("self_loop")
	assert_logged(
		["Entered 5 nodes without pausing (likely a goto cycle); finishing the dialogue."]
	)
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
	assert_bool(engine.is_running()).is_false()


# =====================
# Media outside res:// (issue #57)
# =====================


func test_engine_indexes_and_loads_images_from_an_external_directory() -> void:
	var media_dir: String = create_temp_dir("engine_external_media")
	Image.create(2, 2, false, Image.FORMAT_RGB8).save_png(media_dir.path_join("splash.png"))
	var engine = _new_engine(LINEAR_FIXTURE)
	engine.image_path = media_dir
	add_child(auto_free(engine))
	assert_object(engine.image_service.get_image("splash")).is_instanceof(Texture2D)


# =====================
# Visits
# =====================


func test_visits_count_on_leaving_a_node_and_its_own_goto() -> void:
	var engine = _make_engine(VISITS_FIXTURE)
	_connect_content_log(engine)
	engine.start("hub")
	engine.next()
	engine.next()
	engine.next()
	engine.next()
	assert_that(_narration_log).is_equal(["First time", "Back again", "Back again", "Done"])
	# Two gotos into hub, then the end of its body.
	assert_int(engine.node_service.get_visit_count("hub")).is_equal(3)
	assert_that(engine.variable_service.get_variable("count")).is_equal(2.0)
	assert_that(_signal_log.back()).is_equal("finished_dialogue")


func test_finish_statement_counts_a_visit() -> void:
	var engine = _make_engine(VISITS_FIXTURE)
	engine.start("finisher")
	engine.next()
	assert_int(engine.node_service.get_visit_count("finisher")).is_equal(1)


func test_game_calling_finish_counts_no_visit() -> void:
	var engine = _make_engine(VISITS_FIXTURE)
	engine.start("finisher")
	engine.finish()
	assert_int(engine.node_service.get_visit_count("finisher")).is_equal(0)


func test_nodes_create_no_variables() -> void:
	var engine = _make_engine(VISITS_FIXTURE)
	assert_that(engine.variable_service.get_all_ids()).is_equal(["count"])


# =====================
# Built-in functions
# =====================


func test_built_in_functions_run_inside_set_statements() -> void:
	var engine = _make_engine(FUNCTIONS_FIXTURE)
	engine.start("start")
	assert_that(engine.variable_service.get_variable("hp")).is_equal(0.0)
	var roll: float = engine.variable_service.get_variable("roll")
	assert_bool(roll >= 1.0 and roll <= 6.0 and roll == roundf(roll)).is_true()
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
