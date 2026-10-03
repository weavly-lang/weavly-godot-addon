# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# Pool selection against the compiler-built fixture in storylets/src/storylets.wvl.

const FIXTURE = "res://test/fixtures/integration/storylets/build"


func _make_engine(random_seed: int = 1) -> WeavlyDefaultEngine:
	var engine: WeavlyDefaultEngine = WeavlyDefaultEngine.new()
	engine.dialogue_path = FIXTURE
	engine.random_seed = random_seed
	add_child(auto_free(engine))
	return engine


func test_when_filters_the_pool() -> void:
	assert_array(_make_engine().list_pool(["when_test"])).is_equal(["when_yes"])


func test_higher_priorities_come_first() -> void:
	assert_array(_make_engine().list_pool(["priority_test"])).is_equal(["high", "mid", "low"])


func test_weight_decides_between_equal_priorities() -> void:
	var engine: WeavlyEngine = _make_engine()
	var heavy_first: int = 0
	for i: int in 50:
		var listed: Array[String] = engine.list_pool(["weight_test"])
		assert_array(listed).contains_exactly_in_any_order(["heavy", "light"])
		if listed[0] == "heavy":
			heavy_first += 1
	assert_int(heavy_first).is_greater_equal(48)


func test_equal_weights_shuffle_and_the_same_seed_repeats_the_order() -> void:
	var first: Array = []
	var second: Array = []
	var engine: WeavlyEngine = _make_engine(7)
	var other: WeavlyEngine = _make_engine(7)
	for i: int in 10:
		first.append(engine.list_pool(["shuffle_test"]))
		second.append(other.list_pool(["shuffle_test"]))
	assert_array(first).is_equal(second)
	var orders: Dictionary = {}
	for order: Array in first:
		orders[order] = true
	assert_int(orders.size()).is_greater(1)


# menu: menu_top has priority 1; menu_other (menu.wvl) and menu_zeta, menu_alpha and
# menu_beta (storylets.wvl, in that order) tie. menu_zeta and menu_beta share slot m,
# menu_zeta has weight 1000 and menu_alpha weight 0.
func test_without_shuffle_ties_keep_source_order_and_weight_is_ignored() -> void:
	assert_array(_make_engine().list_pool(["menu"], -1, false)).is_equal(
		["menu_top", "menu_other", "menu_zeta", "menu_alpha"]
	)


func test_without_shuffle_the_order_repeats_on_every_call() -> void:
	var engine: WeavlyEngine = _make_engine()
	var first: Array[String] = engine.list_pool(["menu"], -1, false)
	for i: int in 10:
		assert_array(engine.list_pool(["menu"], -1, false)).is_equal(first)


func test_without_shuffle_limit_and_skip_counts_follow_source_order() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool(["menu"], 2, false)).is_equal(["menu_top", "menu_other"])
	for id: String in ["menu_zeta", "menu_alpha", "menu_beta"]:
		assert_int(engine.node_service.get_skip_count(id)).is_equal(1)
	assert_int(engine.node_service.get_skip_count("menu_top")).is_equal(0)


func test_without_shuffle_the_generator_is_untouched() -> void:
	var engine: WeavlyEngine = _make_engine()
	var state: int = engine.rng.state
	engine.list_pool(["menu"], -1, false)
	engine.peek_pool(["menu"], -1, false)
	assert_int(engine.rng.state).is_equal(state)


func test_peek_pool_without_shuffle_matches_list_pool() -> void:
	var engine: WeavlyEngine = _make_engine()
	var peeked: Array[String] = engine.peek_pool(["menu"], 3, false)
	assert_int(engine.node_service.get_skip_count("menu_alpha")).is_equal(0)
	assert_array(engine.list_pool(["menu"], 3, false)).is_equal(peeked)


func test_with_shuffle_a_weight_of_zero_leaves_the_node_out() -> void:
	assert_bool(_make_engine().list_pool(["menu"]).has("menu_alpha")).is_false()


func test_a_node_is_skipped_when_any_of_its_slots_is_taken() -> void:
	assert_array(_make_engine().list_pool(["slot_test"])).is_equal(["in_abc", "in_d", "free"])


func test_several_pools_list_a_shared_node_once_and_slots_block_across_them() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool(["left", "right"])).is_equal(["both_sides", "left_x"])
	assert_array(engine.list_pool(["right"])).is_equal(["both_sides", "right_x"])


func test_a_limit_takes_the_first_nodes_in_selection_order() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool(["priority_test"], 2)).is_equal(["high", "mid"])
	assert_array(engine.list_pool(["priority_test"], 3)).is_equal(["high", "mid", "low"])
	assert_array(engine.list_pool(["priority_test"], 5)).is_equal(["high", "mid", "low"])
	assert_array(engine.list_pool(["priority_test"], 0)).is_empty()


func test_nodes_past_the_limit_count_as_skipped() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.list_pool(["priority_test"], 1)
	assert_int(engine.node_service.get_skip_count("high")).is_equal(0)
	assert_int(engine.node_service.get_skip_count("mid")).is_equal(1)
	assert_int(engine.node_service.get_skip_count("low")).is_equal(1)


func test_nodes_blocked_by_a_slot_dont_count_toward_the_limit() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool(["slot_test"], 2)).is_equal(["in_abc", "in_d"])
	assert_int(engine.node_service.get_skip_count("in_a")).is_equal(1)
	assert_int(engine.node_service.get_skip_count("free")).is_equal(1)


func test_peek_pool_with_a_limit_matches_list_pool() -> void:
	var engine: WeavlyEngine = _make_engine()
	var peeked: Array[String] = engine.peek_pool(["shuffle_test", "skip_test"], 2)
	assert_int(peeked.size()).is_equal(2)
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(0)
	assert_array(engine.list_pool(["shuffle_test", "skip_test"], 2)).is_equal(peeked)


# Literals in untyped code are untyped arrays, so the pool functions can't require Array[String].
func test_pool_functions_accept_untyped_arrays() -> void:
	var engine: Variant = _make_engine()
	assert_array(engine.list_pool(["priority_test"], 1)).is_equal(["high"])
	assert_array(engine.peek_pool(["priority_test"])).is_equal(["high", "mid", "low"])
	assert_bool(engine.draw(["priority_test"])).is_true()


func test_a_declared_pool_without_members_is_empty() -> void:
	assert_array(_make_engine().list_pool(["unused"])).is_empty()


func test_an_undeclared_pool_is_reported_and_counts_as_empty() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool(["nope", "when_test"])).is_equal(["when_yes"])
	assert_logged(["Pool 'nope' isn't declared."])


func test_a_failing_when_is_reported_at_its_meta_line_and_skips_the_node() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool(["error_test"])).is_equal(["calm"])
	assert_logged(
		["storylets.wvl:166: error: Variable 'mood' is declared extern but was never defined."]
	)


# skip_test: first has priority 2.5, patient has priority skip_count(), both in slot k;
# never isn't eligible.
func test_skip_count_counts_untaken_eligible_nodes_and_resets_taken_ones() -> void:
	var engine: WeavlyEngine = _make_engine()
	for i: int in 3:
		assert_array(engine.list_pool(["skip_test"])).is_equal(["first"])
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(3)
	assert_int(engine.node_service.get_skip_count("never")).is_equal(0)
	assert_array(engine.list_pool(["skip_test"])).is_equal(["patient"])
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(0)
	assert_int(engine.node_service.get_skip_count("first")).is_equal(1)


func test_skip_count_can_be_read_in_a_script() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.list_pool(["skip_test"])
	engine.list_pool(["skip_test"])
	engine.start("count_skips")
	assert_that(engine.variable_service.get_variable("count")).is_equal(2.0)


func test_peek_pool_matches_the_next_list_pool_and_changes_nothing() -> void:
	var engine: WeavlyEngine = _make_engine()
	var peeked: Array[String] = engine.peek_pool(["shuffle_test", "skip_test"])
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(0)
	assert_array(engine.list_pool(["shuffle_test", "skip_test"])).is_equal(peeked)
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(1)


func test_skip_counts_are_saved_and_loaded() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.list_pool(["skip_test"])
	engine.list_pool(["skip_test"])
	var state: Dictionary = JSON.parse_string(JSON.stringify(engine.get_state()))
	engine.list_pool(["skip_test"])
	engine.set_state(state)
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(2)


func test_node_meta_exposes_pools_and_slots() -> void:
	var engine: WeavlyEngine = _make_engine()
	var meta: WeavlyModel.NodeMeta = engine.node_service.get_node("in_abc").meta
	assert_array(meta.pools).is_equal(["slot_test"])
	assert_array(meta.slots).is_equal(["a", "b", "c"])
	assert_object(engine.node_service.get_node("count_skips").meta).is_null()


func test_jump_and_start_ignore_the_metadata() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.start("when_no")
	assert_int(engine.node_service.get_visit_count("when_no")).is_equal(1)


# =====================
# draw and @draw (issue #151)
# =====================


func _record_entered(engine: WeavlyEngine) -> Array[String]:
	var entered: Array[String] = []
	engine.entered_node.connect(func(node_id: String) -> void: entered.append(node_id))
	return entered


func test_draw_starts_the_first_node_in_selection_order() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entered: Array[String] = _record_entered(engine)
	assert_bool(engine.draw(["priority_test"])).is_true()
	assert_array(entered).is_equal(["high"])


func test_draw_selects_over_several_pools() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entered: Array[String] = _record_entered(engine)
	assert_bool(engine.draw(["left", "right"])).is_true()
	assert_array(entered).is_equal(["both_sides"])


func test_draw_without_an_eligible_node_starts_nothing() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entered: Array[String] = _record_entered(engine)
	assert_bool(engine.draw(["unused"])).is_false()
	assert_array(entered).is_empty()
	assert_bool(engine.is_running()).is_false()


func test_draw_while_a_dialogue_runs_warns_and_does_nothing() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.start("talk")
	var entered: Array[String] = _record_entered(engine)
	assert_bool(engine.draw(["skip_test"])).is_false()
	assert_logged([], ["Dialogue is already in progress, can't draw from skip_test."])
	assert_array(entered).is_empty()
	assert_that(engine.current_node_id).is_equal("talk")
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(0)


func test_draw_with_an_undeclared_pool_is_reported() -> void:
	assert_bool(_make_engine().draw(["nope"])).is_false()
	assert_logged(["Pool 'nope' isn't declared."])


func test_draw_resets_the_drawn_node_and_counts_the_other_eligible_ones() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.draw(["skip_test"])
	assert_int(engine.node_service.get_skip_count("first")).is_equal(0)
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(1)
	assert_int(engine.node_service.get_skip_count("never")).is_equal(0)


func test_the_draw_statement_runs_the_drawn_node_like_a_detour() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entered: Array[String] = _record_entered(engine)
	var left: Array[String] = []
	engine.left_node.connect(func(id: String) -> void: left.append(id))
	engine.start("draw_one")
	assert_array(entered).is_equal(["draw_one", "when_yes"])
	assert_array(left).is_equal(["when_yes", "draw_one"])
	assert_that(engine.variable_service.get_variable("count")).is_equal(1.0)
	assert_int(engine.node_service.get_visit_count("draw_one")).is_equal(1)


func test_the_draw_statement_selects_over_several_pools() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entered: Array[String] = _record_entered(engine)
	engine.start("draw_several")
	assert_array(entered).is_equal(["draw_several", "both_sides"])


func test_the_draw_statement_without_an_eligible_node_continues() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entered: Array[String] = _record_entered(engine)
	engine.start("draw_none")
	assert_array(entered).is_equal(["draw_none"])
	assert_that(engine.variable_service.get_variable("count")).is_equal(5.0)


func test_the_draw_statement_counts_a_pool_listed_twice_once() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.start("draw_skips")
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(1)
