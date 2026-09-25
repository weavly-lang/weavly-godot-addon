# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# Malformed-input tests for WeavlyDeserializer (see issue #38).
# A single bad file/node/statement must report an error and be skipped
# gracefully, never crash the deserializer with a typed-assignment failure.


func _build(nodes: Variant) -> Dictionary:
	return {"source": "story.wvl", "nodes": nodes}


func _node(id: String, body: Array) -> Dictionary:
	return {"id": id, "line": 1.0, "body": body}


func _statement(data: Dictionary) -> Dictionary:
	return data.merged({"line": 2.0})


# =====================
# Nodes
# =====================


func test_nodes_missing_top_level_key_returns_empty() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"source": "story.wvl"})
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'nodes' at <root>"])


func test_nodes_wrong_type_returns_empty() -> void:
	var nodes = WeavlyDeserializer.compile_nodes(_build("not an array"))
	assert_that(nodes.size()).is_equal(0)
	assert_logged(
		["Required field 'nodes' has wrong type at <root>, expected 'Array' got 'String'"]
	)


func test_node_missing_body_is_skipped() -> void:
	var nodes = WeavlyDeserializer.compile_nodes(_build([{"id": "start", "line": 1.0}]))
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'body' at nodes[0]"])


func test_node_missing_id_is_skipped() -> void:
	var nodes = WeavlyDeserializer.compile_nodes(_build([{"line": 1.0, "body": []}]))
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'id' at nodes[0]"])


func test_node_missing_line_is_skipped() -> void:
	var nodes = WeavlyDeserializer.compile_nodes(_build([{"id": "start", "body": []}]))
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'line' at nodes[0]"])


func test_nodes_missing_source_returns_empty() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"nodes": [_node("start", [])]})
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'source' at <root>"])


func test_malformed_node_does_not_drop_valid_siblings() -> void:
	var data = _build([{"id": "broken", "line": 1.0}, _node("ok", [])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes.size()).is_equal(1)
	assert_that(nodes[0].id).is_equal("ok")
	assert_logged(["Missing required field 'body' at nodes[0]"])


# =====================
# Statements
# =====================


func test_unknown_statement_type_is_skipped() -> void:
	var data = _build([_node("start", [_statement({"type": "bogus"})])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Unknown statement type 'bogus' at nodes[0].body[0]"])


func test_statement_missing_type_is_skipped() -> void:
	var data = _build([_node("start", [_statement({"text": ["orphan"]})])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Missing required field 'type' at nodes[0].body[0]"])


func test_statement_that_is_not_a_dictionary_is_skipped() -> void:
	var data = _build([_node("start", ["Hi", _statement({"type": "finish"})])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(1)
	assert_logged(["nodes[0].body[0] must be a Dictionary, got String"])


func test_statement_missing_line_is_skipped() -> void:
	var data = _build([_node("start", [{"type": "narration", "text": ["Hi"]}])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Missing required field 'line' at nodes[0].body[0]"])


func test_narration_with_text_that_is_not_a_list_is_skipped() -> void:
	var data = _build([_node("start", [_statement({"type": "narration", "text": "Hi"})])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(
		[
			(
				"Required field 'text' has wrong type at nodes[0].body[0], "
				+ "expected 'Array' got 'String'"
			)
		]
	)


func test_narration_with_a_failing_interpolation_is_skipped() -> void:
	var narration = _statement({"type": "narration", "text": ["a", {"bogus": 1}]})
	var data = _build([_node("start", [narration])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Unknown expression type at nodes[0].body[0].text[1]"])


func test_narration_missing_text_is_skipped() -> void:
	var data = _build([_node("start", [_statement({"type": "narration"})])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Missing required field 'text' at nodes[0].body[0]"])


func test_match_missing_cases_is_skipped() -> void:
	var data = _build([_node("start", [_statement({"type": "match", "modifier": "first"})])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Missing required field 'cases' at nodes[0].body[0]"])


func test_match_unknown_modifier_is_skipped() -> void:
	var case_data = {"line": 3.0, "condition": true, "body": []}
	var match_data = _statement({"type": "match", "modifier": "bogus", "cases": [case_data]})
	var data = _build([_node("start", [match_data])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Unknown match modifier 'bogus' at nodes[0].body[0]"])


func test_match_unknown_modifier_fixture_is_skipped() -> void:
	var path = "res://test/fixtures/deserializer/unknown_match_modifier.json"
	var data = WeavlyFileUtils.load_json_file(path)
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Unknown match modifier 'bogus' at nodes[0].body[0]"])


# =====================
# Variable declarations
# =====================


func test_variable_missing_value_is_skipped() -> void:
	var data = {"declarations": [{"name": "score", "type": "number"}]}
	var vars = WeavlyDeserializer.compile_variable_declarations(data)
	assert_that(vars.size()).is_equal(0)
	assert_logged(["Missing required field 'value' at declarations[0]"])


func test_variable_declaration_non_dictionary_is_skipped() -> void:
	var vars = WeavlyDeserializer.compile_variable_declarations({"declarations": [42]})
	assert_that(vars.size()).is_equal(0)
	assert_logged(["Variable declaration at declarations[0] must be a Dictionary, got int"])


func test_declarations_wrong_type_returns_empty() -> void:
	var vars = WeavlyDeserializer.compile_variable_declarations({"declarations": "nope"})
	assert_that(vars.size()).is_equal(0)
	assert_logged(
		["Required field 'declarations' has wrong type at <root>, expected 'Array' got 'String'"]
	)


# =====================
# Source file attribution
# =====================


func test_node_error_includes_source_file_path() -> void:
	var data = _build([{"id": "start", "line": 1.0}])  # missing body
	WeavlyDeserializer.compile_nodes(data, "res://dialogue/build/scene2.json")
	assert_logged(["Missing required field 'body' at res://dialogue/build/scene2.json > nodes[0]"])


func test_declaration_error_includes_source_file_path() -> void:
	var data = {"declarations": [{"name": "score", "type": "number"}]}  # missing value
	WeavlyDeserializer.compile_variable_declarations(data, "res://dialogue/build/env.json")
	assert_logged(
		["Missing required field 'value' at res://dialogue/build/env.json > declarations[0]"]
	)


# =====================
# Failed parts drop their statement
# =====================


func _body_of(statement: Dictionary) -> Array:
	var data = _build([_node("start", [_statement(statement), _statement({"type": "finish"})])])
	return WeavlyDeserializer.compile_nodes(data)[0].body


func test_set_with_unknown_expression_is_dropped() -> void:
	var body = _body_of({"type": "set", "id": "score", "expression": {"bogus": 1}})
	assert_that(body.size()).is_equal(1)
	assert_that(body[0]).is_instanceof(WeavlyModel.FinishStatement)
	assert_logged(["Unknown expression type at nodes[0].body[0].expression"])


func test_set_missing_expression_reports_once() -> void:
	var body = _body_of({"type": "set", "id": "score"})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Missing required field 'expression' at nodes[0].body[0]"])


func test_set_with_a_failing_nested_operand_is_dropped() -> void:
	var expression = {"op": "+", "left": 1.0, "right": {"op": "not", "expression": {"x": 1}}}
	var body = _body_of({"type": "set", "id": "score", "expression": expression})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Unknown expression type at nodes[0].body[0].expression.right.expression"])


func test_match_with_a_failing_case_condition_is_dropped() -> void:
	var cases = [
		{"line": 3.0, "condition": {"bogus": 1}, "body": []},
		{"line": 4.0, "condition": true, "body": []},
	]
	var body = _body_of({"type": "match", "modifier": "first", "cases": cases})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Unknown expression type at nodes[0].body[0].cases[0].condition"])


func test_option_block_with_a_failing_condition_is_dropped() -> void:
	var items = [
		{"line": 3.0, "condition": {"bogus": 1}, "text": ["a"], "body": [], "hint": false},
		{"line": 4.0, "condition": true, "text": ["b"], "body": [], "hint": false},
	]
	var body = _body_of({"type": "option", "items": items})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Unknown expression type at nodes[0].body[0].items[0].condition"])


func test_random_block_with_a_failing_weight_is_dropped() -> void:
	var cases = [
		{"line": 3.0, "condition": true, "weight": {"bogus": 1}, "body": []},
		{"line": 4.0, "condition": true, "weight": 1.0, "body": []},
	]
	var body = _body_of({"type": "random", "cases": cases})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Unknown expression type at nodes[0].body[0].cases[0].weight"])


func test_a_failing_statement_inside_a_case_body_keeps_the_block() -> void:
	var cases = [{"line": 3.0, "condition": true, "body": [_statement({"type": "bogus"})]}]
	var body = _body_of({"type": "match", "modifier": "first", "cases": cases})
	assert_that(body.size()).is_equal(2)
	assert_that(body[0].cases[0].body).is_empty()
	assert_logged(["Unknown statement type 'bogus' at nodes[0].body[0].cases[0].body[0]"])


func test_command_with_a_failing_argument_is_dropped() -> void:
	var body = _body_of({"type": "command", "id": "shake", "args": [1.0, {"bogus": 1}]})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Unknown expression type at nodes[0].body[0].args[1]"])


func test_command_without_args_is_dropped() -> void:
	var body = _body_of({"type": "command", "id": "shake", "text": "strong"})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Missing required field 'args' at nodes[0].body[0]"])


func test_match_with_a_case_missing_its_line_is_dropped() -> void:
	var cases = [{"condition": true, "body": []}]
	var body = _body_of({"type": "match", "modifier": "first", "cases": cases})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Missing required field 'line' at nodes[0].body[0].cases[0]"])


func test_option_block_with_an_option_missing_its_line_is_dropped() -> void:
	var items = [{"condition": true, "text": ["a"], "body": [], "hint": false}]
	var body = _body_of({"type": "option", "items": items})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Missing required field 'line' at nodes[0].body[0].items[0]"])


func test_random_block_with_a_case_missing_its_line_is_dropped() -> void:
	var cases = [{"condition": true, "weight": 1.0, "body": []}]
	var body = _body_of({"type": "random", "cases": cases})
	assert_that(body.size()).is_equal(1)
	assert_logged(["Missing required field 'line' at nodes[0].body[0].cases[0]"])


# =====================
# Meta
# =====================


func _node_with_meta(meta: Variant) -> Dictionary:
	var node_data: Dictionary = _node("bob", [])
	node_data["meta"] = meta
	return node_data


func test_an_unknown_meta_key_drops_the_node() -> void:
	var data = _build([_node_with_meta({"label": {"line": 2.0, "value": "Bob"}})])
	assert_array(WeavlyDeserializer.compile_nodes(data)).is_empty()
	assert_logged(["Unknown meta key 'label' at nodes[0].meta.label"])


func test_a_pool_name_that_is_not_a_string_drops_the_node() -> void:
	var data = _build([_node_with_meta({"pool": {"line": 2.0, "value": ["city", 3.0]}})])
	assert_array(WeavlyDeserializer.compile_nodes(data)).is_empty()
	assert_logged(["nodes[0].meta.pool.value[1] must be a String, got float"])


func test_a_failing_meta_expression_drops_the_node() -> void:
	var data = _build([_node_with_meta({"when": {"line": 2.0, "value": {"bogus": 1}}})])
	assert_array(WeavlyDeserializer.compile_nodes(data)).is_empty()
	assert_logged(["Unknown expression type at nodes[0].meta.when.value"])


func test_env_without_pools_is_reported() -> void:
	var names: Array[String] = WeavlyDeserializer.compile_pool_names({"declarations": []})
	assert_array(names).is_empty()
	assert_logged(["Missing required field 'pools' at <root>"])
