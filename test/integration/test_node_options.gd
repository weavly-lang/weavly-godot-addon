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
	_engine.line_reached.connect(
		func(line: WeavlyModel.LineStatement) -> void:
			if line is WeavlyModel.NarrationLine:
				_events.append(line.text)
	)
	_engine.entered_node.connect(func(id: String) -> void: _events.append("enter:" + id))
	_engine.left_node.connect(func(id: String) -> void: _events.append("leave:" + id))


func _offered() -> Array[WeavlyModel.Option]:
	return _engine.get_pending_options()


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
	while _engine.is_running() and _engine.get_pending_options().is_empty():
		_engine.next()


func _choose(text: String) -> void:
	_engine.choose(_option(text))
	while _engine.is_running() and _engine.get_pending_options().is_empty():
		_engine.next()


func _set_variable(id: String, value: Variant) -> void:
	_engine.set_variable(id, value)


# =====================
# Offering
# =====================


func test_a_block_offers_every_form_in_written_order() -> void:
	_run_to_options("Camp")
	assert_array(_texts(_offered())).is_equal(["Search", "Something blinks", "Cook", "Scout"])
	(
		assert_array(_offered().map(func(option: WeavlyModel.Option) -> int: return option.state))
		. is_equal([AVAILABLE, TEASER, AVAILABLE, AVAILABLE])
	)
	assert_str(_option("Cook").node_id).is_equal("Cook")
	assert_str(_option("Search").node_id).is_empty()


func test_the_display_rule() -> void:
	assert_str(_engine.get_option("LtOpen").text).is_equal("Open")
	assert_int(_engine.get_option("LtOpen").state).is_equal(AVAILABLE)
	assert_str(_engine.get_option("LtTease").text).is_equal("Tease")
	assert_int(_engine.get_option("LtTease").state).is_equal(TEASER)
	assert_str(_engine.get_option("LtPoor").text).is_equal("Poor")
	assert_int(_engine.get_option("LtPoor").state).is_equal(UNAVAILABLE)
	assert_object(_engine.get_option("LtHidden")).is_null()
	assert_object(_engine.get_option("LtGone")).is_null()


func test_label_keys_are_readable_as_text() -> void:
	assert_str(_engine.get_node_meta("Hack", "label")).is_equal("Hack (-3 energy)")
	assert_str(_engine.get_node_meta("Hack", "label_unavailable")).is_equal(
		"Hack (needs 3 energy)"
	)
	assert_str(_engine.get_node_meta("Cook", "label_teaser")).is_empty()


# =====================
# Choosing
# =====================


func test_a_chosen_node_runs_like_a_detour_and_the_block_continues() -> void:
	_run_to_options("Camp")
	_events.clear()
	_choose("Cook")
	assert_array(_events).is_equal(
		["enter:Cook", "You cook.", "leave:Cook", "Morning.", "leave:Camp"]
	)
	assert_int(_engine.count_service.get_visit_count("Cook")).is_equal(1)


func test_a_jump_in_a_chosen_node_leaves_for_good() -> void:
	_run_to_options("Journey")
	_choose("Go on")
	assert_bool(_events.has("Road.")).is_true()
	assert_bool(_events.has("Back on the journey.")).is_false()


func test_options_inside_a_chosen_node_return_in_order() -> void:
	_run_to_options("Journey")
	_choose("Go deep")
	_choose("Inner")
	(
		assert_array(_events.filter(func(event: String) -> bool: return ":" not in event))
		. is_equal(["Inner.", "Deep end.", "Back on the journey."])
	)


func test_once_and_visits_apply_to_real_nodes_and_inline_options_use_their_node() -> void:
	_run_to_options("Camp")
	_choose("Scout")
	_run_to_options("Camp")
	assert_array(_texts(_offered())).is_equal(
		["Search", "Again", "Something blinks", "Cook", "Sing"]
	)


func test_choosing_a_locked_option_is_refused() -> void:
	_run_to_options("Camp")
	_engine.choose(_option("Something blinks"))
	assert_logged([], ["Can't choose option 'Something blinks' because it's locked."])
	assert_array(_engine.get_pending_options()).is_not_empty()


func test_the_choice_isnt_checked_again() -> void:
	_lucky = true
	_run_to_options("Journey")
	var gamble: WeavlyModel.Option = _option("Gamble")
	_lucky = false
	assert_bool(_engine.choose(gamble)).is_true()
	assert_bool(_events.has("You win.")).is_true()


func test_a_block_where_nothing_can_be_chosen_waits_for_next() -> void:
	_run_to_options("Stuck")
	assert_array(_texts(_offered())).is_equal(["Something blinks"])
	assert_bool(_events.has("After stuck.")).is_false()
	_engine.next()
	assert_bool(_events.has("After stuck.")).is_true()


# =====================
# Pools
# =====================


func test_locked_modes_in_list_pool() -> void:
	var pool: Array = ["locked_test"]
	assert_array(_engine.list_pool(pool, 3, false)).is_equal(["LtOpen", "LtTease", "LtPoor"])
	assert_array(_engine.list_pool(pool, 2, false, WeavlyEngine.Locked.EXTRA)).is_equal(
		["LtOpen", "LtTease", "LtPoor", "LtLast"]
	)
	assert_array(_engine.list_pool(pool, -1, false, WeavlyEngine.Locked.HIDE)).is_equal(
		["LtOpen", "LtLast"]
	)


func test_a_pool_option_uses_its_parameters() -> void:
	_run_to_options("LockedMenu")
	assert_array(_texts(_offered())).is_equal(["Open", "Tease", "Poor", "Last"])


func test_locked_nodes_dont_take_slots_and_teasers_keep_their_skip_count() -> void:
	_engine.count_service.set_skip_count("FireTease", 4)
	assert_array(_engine.list_pool(["fire_test"], -1, false)).is_equal(["FireTease", "FireCook"])
	assert_int(_engine.count_service.get_skip_count("FireTease")).is_equal(4)
	assert_int(_engine.count_service.get_skip_count("FireDance")).is_equal(1)


# =====================
# Snapshot
# =====================


func test_offered_options_stay_as_offered() -> void:
	_run_to_options("Camp")
	var hack: WeavlyModel.Option = _option("Something blinks")
	_set_variable("found", true)
	assert_array(_texts(_offered())).is_equal(["Search", "Something blinks", "Cook", "Scout"])
	assert_int(hack.state).is_equal(TEASER)
	assert_bool(_engine.choose(hack)).is_false()
	assert_logged([], ["Can't choose option 'Something blinks' because it's locked."])


func test_the_chosen_node_reads_its_meta_values_as_they_were_offered() -> void:
	_set_variable("found", true)
	_run_to_options("Camp")
	_set_variable("price", 7.0)
	_engine.choose(_option("Hack (-3 energy)"))
	assert_str(_events.back()).is_equal("Hacked.")
	assert_that(_engine.get_variable("energy")).is_equal(2.0)
	assert_that(_engine.get_variable("paid")).is_equal(3.0)
	assert_that(_engine.get_node_meta("Hack", "cost")).is_equal(3.0)
	_engine.next()
	assert_that(_engine.get_node_meta("Hack", "cost")).is_equal(10.0)


func test_an_offered_option_has_the_default_of_a_declared_key_its_node_leaves_out() -> void:
	_set_variable("found", true)
	_run_to_options("Camp")
	assert_dict(_option("Cook").meta).is_equal({"label": "Cook", "cost": 1.0})
	assert_that(_option("Hack (-3 energy)").meta["cost"]).is_equal(3.0)


# =====================
# Game-side menus
# =====================


func test_get_option_stays_as_offered_and_choose_runs_it_as_a_dialogue() -> void:
	var teaser: WeavlyModel.Option = _engine.get_option("Hack")
	_set_variable("found", true)
	assert_int(teaser.state).is_equal(TEASER)
	var hack: WeavlyModel.Option = _engine.get_option("Hack")
	assert_int(hack.state).is_equal(AVAILABLE)
	_engine.choose(hack)
	assert_bool(_engine.is_running()).is_true()
	assert_that(_engine.get_variable("paid")).is_equal(3.0)


func test_choose_refuses_a_locked_option_from_get_option() -> void:
	_engine.choose(_engine.get_option("Hack"))
	assert_logged([], ["Can't choose option 'Something blinks' because it's locked."])
	assert_bool(_engine.is_running()).is_false()


func test_render_option_runs_the_option_as_rendered() -> void:
	_lucky = true
	var entries: Array[WeavlyModel.Statement] = _engine.render("Journey")
	var block: WeavlyModel.OptionBlock = entries[0]
	var gamble: WeavlyModel.Option = block.options[2]
	_lucky = false
	assert_str((_engine.render_option(gamble)[0] as WeavlyModel.LineStatement).text).is_equal(
		"You win."
	)
	var again: Array[WeavlyModel.Statement] = _engine.render("Journey")
	var go_on: WeavlyModel.Option = (again[0] as WeavlyModel.OptionBlock).options[0]
	(
		assert_array(
			_engine.render_option(go_on).map(
				func(line: WeavlyModel.Statement) -> String: return line.text
			)
		)
		. is_equal(["You go.", "Road."])
	)
