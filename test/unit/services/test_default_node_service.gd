extends GutTest

const Service = preload("res://addons/weavly/src/services/implementations/default_node_service.gd")

var _service


func before_each() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get
# =====================


func test_add_and_get() -> void:
	var node := WeavlyModel.WeavlyNode.new("start", [])
	_service.add_node(node)
	assert_eq(_service.get_node("start"), node)


func test_get_missing_returns_default() -> void:
	assert_null(_service.get_node("missing"))
	assert_push_error(1)


func test_get_missing_returns_provided_default() -> void:
	var fallback := WeavlyModel.WeavlyNode.new("fallback", [])
	assert_eq(_service.get_node("missing", fallback), fallback)
	assert_push_error(1)


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	var first := WeavlyModel.WeavlyNode.new("start", [])
	var second := WeavlyModel.WeavlyNode.new("start", [])
	_service.add_node(first)
	_service.add_node(second)
	assert_engine_error(1)
	assert_eq(_service.get_node("start"), first)


# =====================
# get_all_nodes
# =====================


func test_get_all_nodes_empty() -> void:
	assert_eq(_service.get_all_nodes().size(), 0)


func test_get_all_nodes() -> void:
	var a := WeavlyModel.WeavlyNode.new("a", [])
	var b := WeavlyModel.WeavlyNode.new("b", [])
	_service.add_node(a)
	_service.add_node(b)
	var all_nodes = _service.get_all_nodes()
	assert_eq(all_nodes.size(), 2)
	assert_true(all_nodes.has(a))
	assert_true(all_nodes.has(b))
