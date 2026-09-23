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
