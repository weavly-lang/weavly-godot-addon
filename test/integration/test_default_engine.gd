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
const LOCATIONS_FIXTURE = "res://test/fixtures/integration/locations"
const TEXT_FIXTURE = "res://test/fixtures/integration/text"
const HOLD_FIXTURE = "res://test/fixtures/integration/hold"
const SAVE_FIXTURE = "res://test/fixtures/integration/save"
const HINTS_ONLY_FIXTURE = "res://test/fixtures/integration/hints_only"
const RANDOM_FIXTURE = "res://test/fixtures/integration/random"
const STATEFUL_COMMAND_SERVICE = "res://test/helpers/stateful_command_service.gd"

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
		func(node_id: String) -> void: _signal_log.append("entered_node:%s" % node_id)
	)
	engine.finished_dialogue.connect(func() -> void: _signal_log.append("finished_dialogue"))
	engine.command_service.executed_command.connect(
		func(command: WeavlyModel.CommandStatement) -> void:
			_command_log.append("%s:%s" % [command.id, ",".join(command.values.map(str))])
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


# arrival: a narration with {} and an escaped brace, @draw from the empty pool falls
# through, then @draw city, night plays bob_greets (priority 2, once).
func test_ci_smoke_fixture_draws_lists_and_peeks_storylets() -> void:
	var engine = _make_engine(CI_SMOKE_FIXTURE)
	_connect_content_log(engine)
	var character_lines: Array[String] = []
	engine.line_service.executed_character_line.connect(
		func(line: WeavlyModel.CharacterLine) -> void: character_lines.append(line.text)
	)
	engine.start("arrival")
	assert_that(_narration_log.back()).is_equal("You arrive with 1 points, written as {score}.")
	engine.next()
	assert_that(character_lines.back()).is_equal("Welcome back, Hero. The market waited 1 times.")
	engine.next()
	assert_that(_signal_log.back()).is_equal("finished_dialogue")
	assert_bool(_signal_log.has("entered_node:night_market")).is_false()
	assert_int(engine.node_service.get_skip_count("plaza")).is_equal(1)

	var peeked: Array[String] = engine.peek_pool("city", "night")
	assert_array(peeked).is_equal(["night_market", "plaza"])
	assert_int(engine.node_service.get_skip_count("night_market")).is_equal(1)
	assert_array(engine.list_pool("city", "night")).is_equal(peeked)
	assert_int(engine.node_service.get_skip_count("night_market")).is_equal(0)


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
	(
		assert_that(ids)
		. is_equal(
			[
				"arrival",
				"bob_greets",
				"choices",
				"end",
				"match_node",
				"night_market",
				"plaza",
				"random_node",
				"start",
			]
		)
	)
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


# =====================
# Error locations
# =====================


func _collect_reports(engine: WeavlyEngine) -> Array[Array]:
	var reports: Array[Array] = []
	engine.runtime_error.connect(
		func(message: String, source: String, line: int) -> void:
			reports.append([message, source, line])
	)
	return reports


func test_runtime_errors_name_the_file_and_line_of_the_statement_or_case() -> void:
	var engine = _make_engine(LOCATIONS_FIXTURE)
	var reports: Array[Array] = _collect_reports(engine)
	engine.start("start")
	assert_logged(
		[
			"chapter/story.wvl:2: error: Variable 'scroe' isn't defined.",
			"chapter/story.wvl:4: error: Variable 'missing' isn't defined.",
		]
	)
	(
		assert_that(reports)
		. is_equal(
			[
				["Variable 'scroe' isn't defined.", "chapter/story.wvl", 2],
				["Variable 'missing' isn't defined.", "chapter/story.wvl", 4],
			]
		)
	)


func test_an_error_before_any_node_is_entered_has_no_location() -> void:
	var engine = _make_engine(LOCATIONS_FIXTURE)
	var reports: Array[Array] = _collect_reports(engine)
	engine.start("typo")
	assert_logged(["Can't enter node 'typo' because it doesn't exist, finishing the dialogue."])
	assert_that(reports).is_equal(
		[["Can't enter node 'typo' because it doesn't exist, finishing the dialogue.", "", 0]]
	)


# =====================
# Variables in text
# =====================


func test_lines_and_options_arrive_with_variables_filled_in() -> void:
	var engine = _make_engine(TEXT_FIXTURE)
	var narration: Array[WeavlyModel.NarrationLine] = []
	var characters: Array[WeavlyModel.CharacterLine] = []
	engine.line_service.executed_narration_line.connect(
		func(line: WeavlyModel.NarrationLine) -> void: narration.append(line)
	)
	engine.line_service.executed_character_line.connect(
		func(line: WeavlyModel.CharacterLine) -> void: characters.append(line)
	)
	engine.start("start")
	engine.next()
	engine.next()
	assert_that(narration[0].text).is_equal("Hi Ada, you have 3 coins.")
	assert_that(characters[0].name).is_equal("Ada")
	assert_that(characters[0].text).is_equal("I am Ada.")
	var option: WeavlyModel.Option = engine.option_service.pending_options[0]
	assert_that(option.text).is_equal("Pay 3")
	engine.option_service.choose_option(option)
	assert_that(_signal_log.back()).is_equal("finished_dialogue")


# =====================
# hold / release
# =====================


func _make_holding_engine(holds: int = 1) -> WeavlyEngine:
	var engine = _make_engine(HOLD_FIXTURE)
	_connect_content_log(engine)
	engine.command_service.executed_command.connect(
		func(_command: WeavlyModel.CommandStatement) -> void:
			for i in holds:
				engine.hold()
	)
	return engine


func test_a_hold_in_the_command_handler_stops_the_dialogue_until_released() -> void:
	var engine = _make_holding_engine()
	engine.start("start")
	assert_that(_narration_log).is_empty()
	engine.release()
	assert_that(_narration_log).is_equal(["After"])


func test_next_while_held_does_nothing() -> void:
	var engine = _make_holding_engine()
	engine.start("start")
	engine.next()
	assert_that(_narration_log).is_empty()


func test_two_holds_need_two_releases() -> void:
	var engine = _make_holding_engine(2)
	engine.start("start")
	engine.release()
	assert_that(_narration_log).is_empty()
	engine.release()
	assert_that(_narration_log).is_equal(["After"])


func test_releasing_inside_the_handler_continues_the_same_step() -> void:
	var engine = _make_engine(HOLD_FIXTURE)
	_connect_content_log(engine)
	engine.command_service.executed_command.connect(
		func(_command: WeavlyModel.CommandStatement) -> void:
			engine.hold()
			engine.release()
	)
	engine.start("start")
	assert_that(_narration_log).is_equal(["After"])


func test_a_hold_while_a_line_waits_does_not_advance_on_release() -> void:
	var engine = _make_holding_engine()
	engine.start("start")
	engine.release()
	engine.hold()
	engine.release()
	assert_that(_signal_log.back()).is_not_equal("finished_dialogue")
	engine.next()
	assert_that(_signal_log.back()).is_equal("finished_dialogue")


func test_finish_clears_holds() -> void:
	var engine = _make_engine(HOLD_FIXTURE)
	_connect_content_log(engine)
	engine.command_service.executed_command.connect(
		func(_command: WeavlyModel.CommandStatement) -> void: engine.hold(), CONNECT_ONE_SHOT
	)
	engine.start("start")
	engine.finish()
	engine.start("start")
	assert_that(_narration_log).is_equal(["After"])


func test_release_without_a_hold_warns() -> void:
	var engine = _make_engine(HOLD_FIXTURE)
	engine.release()
	assert_logged([], ["release() was called without a matching hold()."])


# =====================
# Save and load
# =====================


func _through_json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


# start: gold += 5, "In start", goto shop. shop: seen_shop = visited(shop), gold += 1, "In shop".
func _save_in_shop(engine: WeavlyEngine) -> Dictionary:
	engine.start("start")
	engine.next()
	return _through_json(engine.get_state())


func test_a_save_taken_mid_node_replays_that_node_without_applying_it_twice() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	_connect_content_log(engine)
	var state: Dictionary = _save_in_shop(engine)
	assert_that(state["node"]).is_equal("shop")
	engine.next()
	engine.set_state(state)
	assert_bool(engine.is_running()).is_true()
	assert_that(_narration_log.back()).is_equal("In shop")
	assert_that(engine.variable_service.get_variable("gold")).is_equal(6.0)
	assert_int(engine.node_service.get_visit_count("start")).is_equal(1)
	assert_int(engine.node_service.get_visit_count("shop")).is_equal(0)


func test_visited_of_the_current_node_is_the_same_after_a_load() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	var state: Dictionary = _save_in_shop(engine)
	engine.next()
	engine.set_state(state)
	assert_bool(engine.variable_service.get_variable("seen_shop")).is_false()


func test_get_state_outside_a_dialogue_has_no_node() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	var state: Dictionary = engine.get_state()
	assert_bool(state.has("node")).is_false()
	assert_that(state["services"]["variable"]["gold"]).is_equal(0.0)


func test_set_state_while_a_dialogue_runs_stops_it_without_finished_dialogue() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	var idle: Dictionary = engine.get_state()
	engine.start("start")
	engine.set_state(idle)
	assert_bool(engine.is_running()).is_false()
	assert_bool(_signal_log.has("finished_dialogue")).is_false()
	assert_that(engine.variable_service.get_variable("gold")).is_equal(0.0)


func test_a_saved_node_that_no_longer_exists_restores_everything_else() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	engine.set_state({"version": 2, "node": "gone", "services": {"variable": {"gold": 3.0}}})
	assert_logged(["Can't resume at node 'gone' because it no longer exists."])
	assert_that(engine.variable_service.get_variable("gold")).is_equal(3.0)
	assert_bool(engine.is_running()).is_false()


func test_a_state_of_an_unknown_version_restores_nothing() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	engine.set_state({"version": 3, "services": {"variable": {"gold": 3.0}}})
	assert_logged(["Can't load a state of version '3', expected version 2."])
	assert_that(engine.variable_service.get_variable("gold")).is_equal(0.0)


func test_reset_state_starts_a_new_game() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	_save_in_shop(engine)
	engine.next()
	engine.reset_state()
	assert_that(engine.variable_service.get_variable("gold")).is_equal(0.0)
	assert_int(engine.node_service.get_visit_count("start")).is_equal(0)
	assert_bool(engine.is_running()).is_false()


func test_state_loaded_fires_once_and_variable_changed_does_not() -> void:
	var engine = _make_engine(SAVE_FIXTURE)
	var events: Array[String] = []
	engine.state_loaded.connect(func() -> void: events.append("state_loaded"))
	engine.variable_service.variable_changed.connect(
		func(id: String, _value: Variant) -> void: events.append(id)
	)
	engine.set_state({"version": 2, "services": {"variable": {"gold": 3.0}}})
	assert_that(events).is_equal(["state_loaded"])


func test_a_custom_services_state_is_saved_and_restored() -> void:
	var engine = _new_engine(SAVE_FIXTURE)
	engine.command_service_script = load(STATEFUL_COMMAND_SERVICE)
	add_child(auto_free(engine))
	var state: Dictionary = engine.get_state()
	assert_that(state["services"]["command"]).is_equal({"volume": 0.5})
	engine.set_state(_through_json(state))
	assert_that(engine.command_service.restored).is_equal({"volume": 0.5})


# =====================
# Options without a choice
# =====================


func test_a_block_of_only_hints_shows_them_and_continues_on_next() -> void:
	var engine = _make_engine(HINTS_ONLY_FIXTURE)
	_connect_content_log(engine)
	var shown: Array[String] = []
	engine.option_service.options_added.connect(
		func(options: Array[WeavlyModel.Option]) -> void:
			for option: WeavlyModel.Option in options:
				shown.append(option.text)
	)
	engine.start("locked")
	assert_that(shown).is_equal(["Locked door"])
	assert_that(_narration_log).is_empty()
	engine.next()
	assert_that(_narration_log).is_equal(["You walk on"])


func test_a_block_without_an_available_option_is_skipped() -> void:
	var engine = _make_engine(HINTS_ONLY_FIXTURE)
	_connect_content_log(engine)
	engine.start("none")
	assert_that(_narration_log).is_equal(["Nothing to choose"])


# =====================
# Random number generator (issue #149)
# =====================


# start: roll = random(1, 1000000), then @random picks one of the lines A to D.
func _roll(engine: WeavlyEngine) -> Array:
	return [engine.variable_service.get_variable("roll"), _narration_log.back()]


func _seeded_engine(random_seed: int) -> WeavlyEngine:
	var engine: WeavlyDefaultEngine = _new_engine(RANDOM_FIXTURE)
	engine.random_seed = random_seed
	add_child(auto_free(engine))
	_connect_content_log(engine)
	return engine


func _play_rounds(engine: WeavlyEngine, rounds: int) -> Array:
	var rolls: Array = []
	for i: int in rounds:
		engine.start("start")
		rolls.append(_roll(engine))
		engine.next()
	return rolls


func test_the_same_seed_rolls_the_same_values_and_branches() -> void:
	var first: Array = _play_rounds(_seeded_engine(1234), 5)
	var second: Array = _play_rounds(_seeded_engine(1234), 5)
	assert_array(first).is_equal(second)


func test_a_loaded_save_replays_the_same_rolls() -> void:
	var engine: WeavlyEngine = _make_engine(RANDOM_FIXTURE)
	_connect_content_log(engine)
	engine.start("start")
	var state: Dictionary = _through_json(engine.get_state())
	var rolled: Array = _roll(engine)
	engine.next()
	engine.set_state(state)
	assert_array(_roll(engine)).is_equal(rolled)


func test_a_state_without_the_generator_keeps_the_current_one() -> void:
	var engine: WeavlyEngine = _make_engine(RANDOM_FIXTURE)
	var state: Dictionary = engine.get_state()
	state.erase("rng")
	engine.rng.randf()
	var current: int = engine.rng.state
	engine.set_state(state)
	assert_int(engine.rng.state).is_equal(current)


func test_reset_state_with_a_seed_replays_the_first_game() -> void:
	var engine: WeavlyEngine = _seeded_engine(1234)
	var first: Array = _play_rounds(engine, 3)
	engine.reset_state()
	assert_array(_play_rounds(engine, 3)).is_equal(first)


func test_reset_state_without_a_seed_keeps_rolling_on() -> void:
	var engine: WeavlyEngine = _make_engine(RANDOM_FIXTURE)
	engine.rng.randf()
	var current: int = engine.rng.state
	engine.reset_state()
	assert_int(engine.rng.state).is_equal(current)
