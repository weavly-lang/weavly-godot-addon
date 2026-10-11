extends WeavlyTestSuite

# Meta keys against the compiler-built fixture in meta/src.

const FIXTURE = "res://test/fixtures/integration/meta/build"

var _engine: WeavlyEngine
var _errors: Array[String]


func before_test() -> void:
	_errors = []
	_engine = WeavlyEngine.new()
	_engine.dialogue_path = FIXTURE
	_engine.random_seed = 3
	add_child(auto_free(_engine))
	_engine.runtime_error.connect(
		func(message: String, source: String, line: int) -> void:
			_errors.append("%s:%d: %s" % [source, line, message])
	)


func _narration() -> Array[String]:
	var texts: Array[String] = []
	_engine.line_reached.connect(
		func(line: WeavlyModel.LineStatement) -> void:
			if line is WeavlyModel.NarrationLine:
				texts.append(line.text)
	)
	return texts


func test_a_custom_key_returns_its_evaluated_value() -> void:
	assert_that(_engine.get_node_meta("Shop", "cost")).is_equal(7.0)
	assert_that(_engine.get_node_meta("Stall", "tag")).is_equal("fresh")
	_engine.set_variable("gold", 1.0)
	assert_that(_engine.get_node_meta("Shop", "cost")).is_equal(3.0)


func test_a_key_the_node_doesnt_write_returns_its_default() -> void:
	assert_that(_engine.get_node_meta("Stall", "cost")).is_equal(1.0)
	assert_that(_engine.get_node_meta("Plain", "cost")).is_equal(1.0)
	assert_that(_engine.get_node_meta("Plain", "tag")).is_equal("plain")
	assert_bool(_engine.get_node_meta("Plain", "urgent")).is_false()


func test_built_in_keys_return_their_values_and_defaults() -> void:
	assert_array(_engine.get_node_meta("Shop", "pool")).is_equal(["market"])
	assert_array(_engine.get_node_meta("Shop", "slot")).is_equal(["table"])
	assert_array(_engine.get_node_meta("Plain", "pool")).is_empty()
	assert_bool(_engine.get_node_meta("Shop", "available")).is_false()
	assert_that(_engine.get_node_meta("Stall", "priority")).is_equal(7.0)
	assert_that(_engine.get_node_meta("Stall", "weight")).is_equal(2.0)
	assert_bool(_engine.get_node_meta("Plain", "when")).is_true()
	assert_bool(_engine.get_node_meta("Plain", "available")).is_true()
	assert_that(_engine.get_node_meta("Plain", "priority")).is_equal(0.0)
	assert_that(_engine.get_node_meta("Plain", "weight")).is_equal(1.0)


func test_when_includes_once() -> void:
	assert_bool(_engine.get_node_meta("OnceOnly", "when")).is_true()
	_engine.start("OnceOnly")
	_engine.next()
	assert_bool(_engine.get_node_meta("OnceOnly", "when")).is_false()


func test_a_returned_list_is_a_copy() -> void:
	var pools: Array = _engine.get_node_meta("Shop", "pool")
	pools.append("other")
	assert_array(_engine.get_node_meta("Shop", "pool")).is_equal(["market"])


func test_an_unknown_node_reports_and_returns_null() -> void:
	assert_object(_engine.get_node_meta("nowhere", "cost")).is_null()
	assert_logged(["Can't read meta key 'cost' of node 'nowhere' because the node doesn't exist."])


func test_an_undeclared_key_reports_and_returns_null() -> void:
	assert_object(_engine.get_node_meta("Shop", "price")).is_null()
	assert_logged(["Can't read meta key 'price' of node 'Shop' because the key isn't declared."])


func test_a_failing_entry_reports_at_its_own_line_and_returns_null() -> void:
	_engine.start("Shop")
	var line: int = _engine.current_line
	assert_object(_engine.get_node_meta("Moody", "urgent")).is_null()
	assert_array(_errors).is_equal(
		["market.wvl:13: Variable 'mood' is declared extern but was never defined."]
	)
	assert_logged(["market.wvl:13: error: Variable 'mood'"])
	assert_str(_engine.current_source).is_equal("shop.wvl")
	assert_int(_engine.current_line).is_equal(line)


func test_a_failure_in_a_read_meta_value_points_to_the_innermost_entry() -> void:
	assert_object(_engine.get_node_meta("Chain", "cost")).is_null()
	assert_array(_errors).is_equal(
		["market.wvl:14: Variable 'bonus' is declared extern but was never defined."]
	)
	assert_logged(["bonus"])


func test_a_value_of_the_wrong_type_reports_and_returns_null() -> void:
	var meta: WeavlyModel.NodeMeta = _engine.story.get_node("Stall").meta
	meta.entries["tag"].expression = WeavlyModel.Number.new(2.0)
	assert_object(_engine.get_node_meta("Stall", "tag")).is_null()
	assert_array(_errors).is_equal(
		["market.wvl:4: Meta key 'tag' of node 'Stall' can't be of type 'float'."]
	)
	assert_logged(["can't be of type"])


func test_get_node_meta_leaves_the_generator_as_it_was() -> void:
	var state: int = _engine.rng.state
	var first: Variant = _engine.get_node_meta("Lucky", "cost")
	assert_int(_engine.rng.state).is_equal(state)
	assert_that(_engine.get_node_meta("Lucky", "cost")).is_equal(first)


func test_meta_in_a_script_reads_the_value() -> void:
	var texts: Array[String] = _narration()
	_engine.start("Shop")
	assert_that(_engine.get_variable("paid")).is_equal(7.0)
	assert_array(texts).is_equal(["Fresh."])


func test_meta_in_a_script_uses_the_generator() -> void:
	var state: int = _engine.rng.state
	var expected: Variant = _engine.get_node_meta("Lucky", "cost")
	_engine.start("Lucky")
	assert_that(_engine.get_variable("rolled")).is_equal(expected)
	assert_int(_engine.rng.state).is_not_equal(state)


func test_a_failing_meta_in_a_script_fails_its_condition() -> void:
	var texts: Array[String] = _narration()
	_engine.start("MoodyCheck")
	assert_array(texts).is_equal(["After."])
	assert_array(_errors).is_equal(
		["market.wvl:13: Variable 'mood' is declared extern but was never defined."]
	)
	assert_logged(["mood"])


# shop costs more than the gold there is and has no label_unavailable, so it's hidden.
func test_the_selector_reads_meta_values() -> void:
	assert_array(_engine.list_pool(["market"])).is_equal(["Stall"])
