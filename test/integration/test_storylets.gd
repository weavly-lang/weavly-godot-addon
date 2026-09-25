extends WeavlyTestSuite

# Pool selection against the compiler-built fixture in storylets/src/storylets.wvl.

const FIXTURE = "res://test/fixtures/integration/storylets/build"


func _make_engine(random_seed: int = 1) -> WeavlyDefaultEngine:
	var engine: WeavlyDefaultEngine = WeavlyDefaultEngine.new()
	engine.dialogue_path = FIXTURE
	engine.video_path = FIXTURE
	engine.image_path = FIXTURE
	engine.character_path = FIXTURE
	engine.variable_path = FIXTURE
	engine.random_seed = random_seed
	add_child(auto_free(engine))
	return engine


func test_when_filters_the_pool() -> void:
	assert_array(_make_engine().list_pool("when_test")).is_equal(["when_yes"])


func test_higher_priorities_come_first() -> void:
	assert_array(_make_engine().list_pool("priority_test")).is_equal(["high", "mid", "low"])


func test_weight_decides_between_equal_priorities() -> void:
	var engine: WeavlyEngine = _make_engine()
	var heavy_first: int = 0
	for i: int in 50:
		var listed: Array[String] = engine.list_pool("weight_test")
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
		first.append(engine.list_pool("shuffle_test"))
		second.append(other.list_pool("shuffle_test"))
	assert_array(first).is_equal(second)
	var orders: Dictionary = {}
	for order: Array in first:
		orders[order] = true
	assert_int(orders.size()).is_greater(1)


func test_a_node_is_skipped_when_any_of_its_slots_is_taken() -> void:
	assert_array(_make_engine().list_pool("slot_test")).is_equal(["in_abc", "in_d", "free"])


func test_several_pools_list_a_shared_node_once_and_slots_block_across_them() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool("left", "right")).is_equal(["both_sides", "left_x"])
	assert_array(engine.list_pool("right")).is_equal(["both_sides", "right_x"])


func test_a_declared_pool_without_members_is_empty() -> void:
	assert_array(_make_engine().list_pool("unused")).is_empty()


func test_an_undeclared_pool_is_reported_and_counts_as_empty() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool("nope", "when_test")).is_equal(["when_yes"])
	assert_logged(["Pool 'nope' isn't declared."])


func test_a_failing_when_is_reported_at_its_meta_line_and_skips_the_node() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.list_pool("error_test")).is_equal(["calm"])
	assert_logged(
		["storylets.wvl:166: error: Variable 'mood' is declared extern but was never defined."]
	)


# skip_test: first has priority 2.5, patient has priority skip_count(), both in slot k;
# never isn't eligible.
func test_skip_count_counts_untaken_eligible_nodes_and_resets_taken_ones() -> void:
	var engine: WeavlyEngine = _make_engine()
	for i: int in 3:
		assert_array(engine.list_pool("skip_test")).is_equal(["first"])
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(3)
	assert_int(engine.node_service.get_skip_count("never")).is_equal(0)
	assert_array(engine.list_pool("skip_test")).is_equal(["patient"])
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(0)
	assert_int(engine.node_service.get_skip_count("first")).is_equal(1)


func test_skip_count_can_be_read_in_a_script() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.list_pool("skip_test")
	engine.list_pool("skip_test")
	engine.start("count_skips")
	assert_that(engine.variable_service.get_variable("count")).is_equal(2.0)


func test_peek_pool_matches_the_next_list_pool_and_changes_nothing() -> void:
	var engine: WeavlyEngine = _make_engine()
	var peeked: Array[String] = engine.peek_pool("shuffle_test", "skip_test")
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(0)
	assert_array(engine.list_pool("shuffle_test", "skip_test")).is_equal(peeked)
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(1)


func test_skip_counts_are_saved_and_loaded() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.list_pool("skip_test")
	engine.list_pool("skip_test")
	var state: Dictionary = JSON.parse_string(JSON.stringify(engine.get_state()))
	engine.list_pool("skip_test")
	engine.set_state(state)
	assert_int(engine.node_service.get_skip_count("patient")).is_equal(2)


func test_get_node_meta_exposes_pools_and_slots() -> void:
	var engine: WeavlyEngine = _make_engine()
	var meta: WeavlyModel.NodeMeta = engine.node_service.get_node_meta("in_abc")
	assert_array(meta.pools).is_equal(["slot_test"])
	assert_array(meta.slots).is_equal(["a", "b", "c"])
	assert_object(engine.node_service.get_node_meta("count_skips")).is_null()


func test_goto_and_start_ignore_the_metadata() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.start("when_no")
	assert_int(engine.node_service.get_visit_count("when_no")).is_equal(1)
