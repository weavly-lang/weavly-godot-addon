extends WeavlyTestSuite

const Service = preload("res://addons/weavly/src/services/implementations/default_node_service.gd")

var _service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get
# =====================


func test_add_and_get() -> void:
	var node := WeavlyModel.WeavlyNode.new("start", [])
	_service.add_node(node)
	assert_that(_service.get_node("start")).is_equal(node)


func test_get_missing_returns_default() -> void:
	assert_that(_service.get_node("missing")).is_null()
	assert_logged(["Node with id 'missing' doesn't exist"])


func test_get_missing_returns_provided_default() -> void:
	var fallback := WeavlyModel.WeavlyNode.new("fallback", [])
	assert_that(_service.get_node("missing", fallback)).is_equal(fallback)
	assert_logged(["Node with id 'missing' doesn't exist"])


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	var first := WeavlyModel.WeavlyNode.new("start", [])
	var second := WeavlyModel.WeavlyNode.new("start", [])
	_service.add_node(first)
	_service.add_node(second)
	assert_logged([], ["Node with id 'start' already exists."])
	assert_that(_service.get_node("start")).is_equal(first)


# =====================
# get_all_nodes
# =====================


func test_get_all_nodes_empty() -> void:
	assert_that(_service.get_all_nodes().size()).is_equal(0)


func test_get_all_nodes() -> void:
	var a := WeavlyModel.WeavlyNode.new("a", [])
	var b := WeavlyModel.WeavlyNode.new("b", [])
	_service.add_node(a)
	_service.add_node(b)
	var all_nodes = _service.get_all_nodes()
	assert_that(all_nodes.size()).is_equal(2)
	assert_bool(all_nodes.has(a)).is_true()
	assert_bool(all_nodes.has(b)).is_true()


# =====================
# visits
# =====================


func test_visit_count_is_zero_before_any_visit() -> void:
	assert_int(_service.get_visit_count("start")).is_equal(0)


func test_record_visit_counts_up() -> void:
	_service.record_visit("start")
	_service.record_visit("start")
	assert_int(_service.get_visit_count("start")).is_equal(2)
	assert_int(_service.get_visit_count("other")).is_equal(0)


# =====================
# get_state / set_state
# =====================


func test_state_round_trips_visit_and_skip_counts_as_ints() -> void:
	_service.add_node(WeavlyModel.WeavlyNode.new("start", []))
	_service.record_visit("start")
	_service.set_skip_count("start", 2)
	assert_that(_service.get_state()).is_equal({"visits": {"start": 1}, "skips": {"start": 2}})
	_service.set_state({"visits": {"start": 3.0}, "skips": {"start": 4.0}})
	assert_int(_service.get_visit_count("start")).is_equal(3)
	assert_int(_service.get_skip_count("start")).is_equal(4)


func test_set_state_replaces_the_counts() -> void:
	_service.add_node(WeavlyModel.WeavlyNode.new("start", []))
	_service.add_node(WeavlyModel.WeavlyNode.new("other", []))
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


# =====================
# Pools and skip counts
# =====================


func _storylet(id: String, pools: Array[String]) -> WeavlyModel.WeavlyNode:
	var node: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new(id, [])
	node.meta = WeavlyModel.NodeMeta.new()
	node.meta.pools = pools
	return node


func test_nodes_are_indexed_by_pool_in_the_order_they_are_added() -> void:
	_service.add_node(_storylet("b", ["city"]))
	_service.add_node(_storylet("a", ["city", "night"]))
	_service.add_node(WeavlyModel.WeavlyNode.new("plain", []))
	assert_array(_service.get_pool_members("city")).is_equal(["b", "a"])
	assert_array(_service.get_pool_members("night")).is_equal(["a"])
	assert_array(_service.get_pool_members("empty")).is_empty()


func test_add_pool_declares_a_pool() -> void:
	_service.add_pool("city")
	assert_bool(_service.has_pool("city")).is_true()
	assert_bool(_service.has_pool("night")).is_false()


func test_skip_count_is_zero_until_set() -> void:
	assert_int(_service.get_skip_count("a")).is_equal(0)
	_service.set_skip_count("a", 3)
	assert_int(_service.get_skip_count("a")).is_equal(3)
