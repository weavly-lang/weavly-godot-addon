# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# Options as nodes against the compiler-built fixture in node_options/src.

const FIXTURE = "res://test/fixtures/integration/node_options/build"
const AVAILABLE = WeavlyModel.Option.State.AVAILABLE
const UNAVAILABLE = WeavlyModel.Option.State.UNAVAILABLE
const TEASER = WeavlyModel.Option.State.TEASER

var _engine: WeavlyEngine
var _events: Array[String]
var _lucky: bool = false


func before_test() -> void:
	_events = []
	_lucky = false
	_engine = WeavlyEngine.new()
	_engine.dialogue_path = FIXTURE
	add_child(auto_free(_engine))
	_engine.register_function("lucky", func() -> bool: return _lucky)
	_engine.line_service.executed_narration_line.connect(
		func(line: WeavlyModel.NarrationLine) -> void: _events.append(line.text)
	)
	_engine.entered_node.connect(func(id: String) -> void: _events.append("enter:" + id))
	_engine.left_node.connect(func(id: String) -> void: _events.append("leave:" + id))


func _offered() -> Array[WeavlyModel.Option]:
	return _engine.option_service.get_options()


func _texts(options: Array[WeavlyModel.Option]) -> Array[String]:
	var texts: Array[String] = []
	for option: WeavlyModel.Option in options:
		texts.append(option.text)
	return texts


func _option(text: String) -> WeavlyModel.Option:
	for option: WeavlyModel.Option in _offered():
		if option.text == text:
			return option
	return null


# Runs until the next option block, choosing nothing.
func _run_to_options(node_id: String) -> void:
	_engine.start(node_id)
	while _engine.is_running() and not _engine.option_service.has_options():
		_engine.next()


func _choose(text: String) -> void:
	_engine.choose(_option(text))
	while _engine.is_running() and not _engine.option_service.has_options():
		_engine.next()


func _set_variable(id: String, value: Variant) -> void:
	_engine.set_variable(id, value)


# =====================
# Offering
# =====================


func test_a_block_offers_every_form_in_written_order() -> void:
	_run_to_options("camp")
	assert_array(_texts(_offered())).is_equal(["Search", "Something blinks", "Cook", "Scout"])
	(
		assert_array(_offered().map(func(option: WeavlyModel.Option) -> int: return option.state))
		. is_equal([AVAILABLE, TEASER, AVAILABLE, AVAILABLE])
	)
	assert_str(_option("Cook").node_id).is_equal("cook")
	assert_str(_option("Search").node_id).is_empty()


func test_the_display_rule() -> void:
	assert_str(_engine.get_option("lt_open").text).is_equal("Open")
	assert_int(_engine.get_option("lt_open").state).is_equal(AVAILABLE)
	assert_str(_engine.get_option("lt_tease").text).is_equal("Tease")
	assert_int(_engine.get_option("lt_tease").state).is_equal(TEASER)
	assert_str(_engine.get_option("lt_poor").text).is_equal("Poor")
	assert_int(_engine.get_option("lt_poor").state).is_equal(UNAVAILABLE)
	assert_object(_engine.get_option("lt_hidden")).is_null()
	assert_object(_engine.get_option("lt_gone")).is_null()


func test_label_keys_are_readable_as_text() -> void:
	assert_str(_engine.get_node_meta("hack", "label")).is_equal("Hack (-3 energy)")
	assert_str(_engine.get_node_meta("hack", "label_unavailable")).is_equal(
		"Hack (needs 3 energy)"
	)
	assert_str(_engine.get_node_meta("cook", "label_teaser")).is_empty()


# =====================
# Choosing
# =====================


func test_a_chosen_node_runs_like_a_detour_and_the_block_continues() -> void:
	_run_to_options("camp")
	_events.clear()
	_choose("Cook")
	assert_array(_events).is_equal(
		["enter:cook", "You cook.", "leave:cook", "Morning.", "leave:camp"]
	)
	assert_int(_engine.count_service.get_visit_count("cook")).is_equal(1)


func test_a_jump_in_a_chosen_node_leaves_for_good() -> void:
	_run_to_options("journey")
	_choose("Go on")
	assert_bool(_events.has("Road.")).is_true()
	assert_bool(_events.has("Back on the journey.")).is_false()


func test_options_inside_a_chosen_node_return_in_order() -> void:
	_run_to_options("journey")
	_choose("Go deep")
	_choose("Inner")
	(
		assert_array(_events.filter(func(event: String) -> bool: return ":" not in event))
		. is_equal(["Inner.", "Deep end.", "Back on the journey."])
	)


func test_once_and_visits_apply_to_real_nodes_and_inline_options_use_their_node() -> void:
	_run_to_options("camp")
	_choose("Scout")
	_run_to_options("camp")
	assert_array(_texts(_offered())).is_equal(
		["Search", "Again", "Something blinks", "Cook", "Sing"]
	)


func test_choosing_a_locked_option_is_refused() -> void:
	_run_to_options("camp")
	_engine.choose(_option("Something blinks"))
	assert_logged([], ["Can't choose option 'Something blinks' because it's locked."])
	assert_bool(_engine.option_service.has_options()).is_true()


func test_the_choice_is_checked_again() -> void:
	_lucky = true
	_run_to_options("journey")
	var gamble: WeavlyModel.Option = _option("Gamble")
	_lucky = false
	_engine.choose(gamble)
	assert_logged([], ["because it's locked."])
	assert_str(gamble.text).is_equal("No luck")


func test_a_block_where_nothing_can_be_chosen_waits_for_next() -> void:
	_run_to_options("stuck")
	assert_array(_texts(_offered())).is_equal(["Something blinks"])
	assert_bool(_events.has("After stuck.")).is_false()
	_engine.next()
	assert_bool(_events.has("After stuck.")).is_true()


# =====================
# Pools
# =====================


func test_locked_modes_in_list_pool() -> void:
	var pool: Array = ["locked_test"]
	assert_array(_engine.list_pool(pool, 3, false)).is_equal(["lt_open", "lt_tease", "lt_poor"])
	assert_array(_engine.list_pool(pool, 2, false, WeavlyEngine.Locked.EXTRA)).is_equal(
		["lt_open", "lt_tease", "lt_poor", "lt_last"]
	)
	assert_array(_engine.list_pool(pool, -1, false, WeavlyEngine.Locked.HIDE)).is_equal(
		["lt_open", "lt_last"]
	)


func test_a_pool_option_uses_its_parameters() -> void:
	_run_to_options("locked_menu")
	assert_array(_texts(_offered())).is_equal(["Open", "Tease", "Poor", "Last"])


func test_locked_nodes_dont_take_slots_and_teasers_keep_their_skip_count() -> void:
	_engine.count_service.set_skip_count("fire_tease", 4)
	assert_array(_engine.list_pool(["fire_test"], -1, false)).is_equal(["fire_tease", "fire_cook"])
	assert_int(_engine.count_service.get_skip_count("fire_tease")).is_equal(4)
	assert_int(_engine.count_service.get_skip_count("fire_dance")).is_equal(1)


# =====================
# Refresh
# =====================


func test_a_variable_change_refreshes_offered_options_in_place() -> void:
	_run_to_options("camp")
	var refreshed: Array[int] = [0]
	_engine.options_refreshed.connect(func() -> void: refreshed[0] += 1)
	var hack: WeavlyModel.Option = _option("Something blinks")
	var search: WeavlyModel.Option = _option("Search")
	_set_variable("found", true)
	assert_int(refreshed[0]).is_equal(1)
	assert_str(hack.text).is_equal("Hack (-3 energy)")
	assert_int(hack.state).is_equal(AVAILABLE)
	assert_bool(search.hidden).is_true()
	_set_variable("energy", 1.0)
	assert_str(hack.text).is_equal("Hack (needs 3 energy)")
	assert_int(hack.state).is_equal(UNAVAILABLE)


func test_a_refresh_keeps_the_offered_selection() -> void:
	_run_to_options("camp")
	_set_variable("found", true)
	assert_array(_texts(_offered())).is_equal(["Search", "Hack (-3 energy)", "Cook", "Scout"])


func test_refresh_options_covers_game_owned_state() -> void:
	_run_to_options("journey")
	var gamble: WeavlyModel.Option = _option("No luck")
	_lucky = true
	assert_str(gamble.text).is_equal("No luck")
	_engine.refresh_options()
	assert_str(gamble.text).is_equal("Gamble")
	assert_bool(gamble.is_choosable()).is_true()


# =====================
# Snapshot
# =====================


func test_the_chosen_node_reads_its_meta_values_as_they_were_at_the_choice() -> void:
	_set_variable("found", true)
	_run_to_options("camp")
	_engine.choose(_option("Hack (-3 energy)"))
	assert_str(_events.back()).is_equal("Hacked.")
	assert_that(_engine.get_variable("energy")).is_equal(2.0)
	assert_that(_engine.get_variable("paid")).is_equal(3.0)
	assert_that(_engine.get_node_meta("hack", "cost")).is_equal(3.0)
	_engine.next()
	assert_that(_engine.get_node_meta("hack", "cost")).is_equal(10.0)


# =====================
# Game-side menus
# =====================


func test_get_option_is_live_and_choose_runs_it_as_a_dialogue() -> void:
	var hack: WeavlyModel.Option = _engine.get_option("hack")
	assert_int(hack.state).is_equal(TEASER)
	_set_variable("found", true)
	assert_int(hack.state).is_equal(AVAILABLE)
	_engine.choose(hack)
	assert_bool(_engine.is_running()).is_true()
	assert_that(_engine.get_variable("paid")).is_equal(3.0)


func test_choose_refuses_a_locked_option_from_get_option() -> void:
	_engine.choose(_engine.get_option("hack"))
	assert_logged([], ["Can't choose option 'Something blinks' because it's locked."])
	assert_bool(_engine.is_running()).is_false()


func test_render_option_checks_the_choice_again() -> void:
	_lucky = true
	var entries: Array[WeavlyModel.Statement] = _engine.render("journey")
	var block: WeavlyModel.OptionBlock = entries[0]
	var gamble: WeavlyModel.Option = block.options[2]
	_lucky = false
	assert_array(_engine.render_option(gamble)).is_empty()
	assert_logged([], ["because it's locked."])
	var again: Array[WeavlyModel.Statement] = _engine.render("journey")
	var go_on: WeavlyModel.Option = (again[0] as WeavlyModel.OptionBlock).options[0]
	(
		assert_array(
			_engine.render_option(go_on).map(
				func(line: WeavlyModel.Statement) -> String: return line.text
			)
		)
		. is_equal(["You go.", "Road."])
	)
