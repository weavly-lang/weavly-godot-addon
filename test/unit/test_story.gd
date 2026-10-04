extends WeavlyTestSuite

var _story: WeavlyStory


func before_test() -> void:
	_story = WeavlyStory.new()


func _storylet(id: String, pools: Array[String]) -> WeavlyModel.WeavlyNode:
	var node: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new(id, [])
	node.meta = WeavlyModel.NodeMeta.new()
	node.meta.pools = pools
	return node


# =====================
# Nodes
# =====================


func test_add_and_get_a_node() -> void:
	var node: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new("start", [])
	_story.add_node(node)
	assert_bool(_story.has_node("start")).is_true()
	assert_that(_story.get_node("start")).is_equal(node)


func test_a_missing_node_is_null() -> void:
	assert_bool(_story.has_node("missing")).is_false()
	assert_that(_story.get_node("missing")).is_null()


func test_a_duplicate_node_is_ignored() -> void:
	var first: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new("start", [])
	_story.add_node(first)
	_story.add_node(WeavlyModel.WeavlyNode.new("start", []))
	assert_logged([], ["Node with id 'start' already exists."])
	assert_that(_story.get_node("start")).is_equal(first)


func test_get_nodes_returns_every_node() -> void:
	assert_array(_story.get_nodes()).is_empty()
	var a: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new("a", [])
	var b: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new("b", [])
	_story.add_node(a)
	_story.add_node(b)
	assert_array(_story.get_nodes()).contains_exactly_in_any_order([a, b])


# =====================
# Pools, slots and meta keys
# =====================


func test_nodes_are_indexed_by_pool_in_the_order_they_are_added() -> void:
	_story.add_node(_storylet("b", ["city"]))
	_story.add_node(_storylet("a", ["city", "night"]))
	_story.add_node(WeavlyModel.WeavlyNode.new("plain", []))
	assert_array(_story.get_pool_members("city")).is_equal(["b", "a"])
	assert_array(_story.get_pool_members("night")).is_equal(["a"])
	assert_array(_story.get_pool_members("empty")).is_empty()


func test_add_pool_declares_a_pool() -> void:
	_story.add_pool("city")
	assert_bool(_story.has_pool("city")).is_true()
	assert_bool(_story.has_pool("night")).is_false()
	assert_array(_story.get_pools()).is_equal(["city"])


func test_add_slot_declares_a_slot() -> void:
	_story.add_slot("bob")
	assert_bool(_story.has_slot("bob")).is_true()
	assert_bool(_story.has_slot("ann")).is_false()
	assert_array(_story.get_slots()).is_equal(["bob"])


func test_a_declared_meta_key_keeps_its_default() -> void:
	_story.add_meta_key("cost", 1.0)
	assert_bool(_story.has_meta_key("cost")).is_true()
	assert_that(_story.get_meta_default("cost")).is_equal(1.0)


func test_an_undeclared_meta_key_has_no_default() -> void:
	assert_bool(_story.has_meta_key("cost")).is_false()
	assert_object(_story.get_meta_default("cost")).is_null()


func test_has_name_looks_in_the_types_declarations() -> void:
	_story.add_node(WeavlyModel.WeavlyNode.new("start", []))
	_story.add_pool("city")
	_story.add_slot("bob")
	assert_bool(_story.has_name("node", "start")).is_true()
	assert_bool(_story.has_name("pool", "city")).is_true()
	assert_bool(_story.has_name("slot", "bob")).is_true()
	assert_bool(_story.has_name("node", "city")).is_false()
	assert_bool(_story.has_name("string", "start")).is_false()


# =====================
# Declarations
# =====================


func test_variables_functions_and_commands_are_declared_by_name() -> void:
	var gold: WeavlyModel.NumberVariable = WeavlyModel.NumberVariable.new("gold", 0.0, null, null)
	var bonus: WeavlyModel.Signature = WeavlyModel.Signature.new("bonus", [], "number")
	var wave: WeavlyModel.Signature = WeavlyModel.Signature.new("wave", [])
	_story.add_variable(gold)
	_story.add_function(bonus)
	_story.add_command(wave)
	assert_that(_story.get_variable("gold")).is_equal(gold)
	assert_array(_story.get_variable_ids()).is_equal(["gold"])
	assert_that(_story.get_function("bonus")).is_equal(bonus)
	assert_array(_story.get_function_names()).is_equal(["bonus"])
	assert_that(_story.get_command("wave")).is_equal(wave)
	assert_array(_story.get_command_names()).is_equal(["wave"])
	assert_object(_story.get_variable("missing")).is_null()


# =====================
# fit
# =====================


func test_fit_checks_the_type_and_counts_ints_as_numbers() -> void:
	assert_int(_story.fit("number", 3)).is_equal(WeavlyStory.Fit.FITS)
	assert_int(_story.fit("number", 3.5)).is_equal(WeavlyStory.Fit.FITS)
	assert_int(_story.fit("string", "x")).is_equal(WeavlyStory.Fit.FITS)
	assert_int(_story.fit("flag", true)).is_equal(WeavlyStory.Fit.FITS)
	assert_int(_story.fit("number", "3")).is_equal(WeavlyStory.Fit.WRONG_TYPE)
	assert_int(_story.fit("flag", null)).is_equal(WeavlyStory.Fit.WRONG_TYPE)


func test_fit_needs_a_declared_name_for_a_name_type() -> void:
	_story.add_pool("city")
	assert_int(_story.fit("pool", "city")).is_equal(WeavlyStory.Fit.FITS)
	assert_int(_story.fit("pool", "harbor")).is_equal(WeavlyStory.Fit.UNKNOWN_NAME)
	assert_int(_story.fit("pool", 1.0)).is_equal(WeavlyStory.Fit.WRONG_TYPE)
