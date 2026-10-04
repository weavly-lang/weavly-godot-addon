extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _service: WeavlyDefaultCountService


func before_test() -> void:
	var engine: FakeEngine = auto_free(FakeEngine.new())
	engine.story.add_node(WeavlyModel.WeavlyNode.new("start", []))
	engine.story.add_node(WeavlyModel.WeavlyNode.new("other", []))
	_service = engine.count_service


func test_visit_count_is_zero_before_any_visit() -> void:
	assert_int(_service.get_visit_count("start")).is_equal(0)


func test_record_visit_counts_up() -> void:
	_service.record_visit("start")
	_service.record_visit("start")
	assert_int(_service.get_visit_count("start")).is_equal(2)
	assert_int(_service.get_visit_count("other")).is_equal(0)


func test_skip_count_is_zero_until_set() -> void:
	assert_int(_service.get_skip_count("start")).is_equal(0)
	_service.set_skip_count("start", 3)
	assert_int(_service.get_skip_count("start")).is_equal(3)


# =====================
# get_state / set_state
# =====================


func test_state_round_trips_visit_and_skip_counts_as_ints() -> void:
	_service.record_visit("start")
	_service.set_skip_count("start", 2)
	assert_that(_service.get_state()).is_equal({"visits": {"start": 1}, "skips": {"start": 2}})
	_service.set_state({"visits": {"start": 3.0}, "skips": {"start": 4.0}})
	assert_int(_service.get_visit_count("start")).is_equal(3)
	assert_int(_service.get_skip_count("start")).is_equal(4)


func test_set_state_replaces_the_counts() -> void:
	_service.record_visit("other")
	_service.set_skip_count("other", 1)
	_service.set_state({"visits": {"start": 1.0}})
	assert_int(_service.get_visit_count("other")).is_equal(0)
	assert_int(_service.get_skip_count("other")).is_equal(0)


func test_set_state_skips_a_node_that_no_longer_exists() -> void:
	_service.set_state({"visits": {"gone": 2.0}, "skips": {"gone": 1.0}})
	assert_int(_service.get_visit_count("gone")).is_equal(0)
	assert_int(_service.get_skip_count("gone")).is_equal(0)
	assert_logged([], ["Saved counts of node 'gone' are skipped because it no longer exists."])
