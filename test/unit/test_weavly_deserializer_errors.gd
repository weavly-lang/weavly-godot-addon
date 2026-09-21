extends WeavlyTestSuite

# Malformed-input tests for WeavlyDeserializer (see issue #38).
# A single bad file/node/statement must report an error and be skipped
# gracefully, never crash the deserializer with a typed-assignment failure.


func _node(id: String, body: Array) -> Dictionary:
	return {"id": id, "body": body}


# =====================
# Nodes
# =====================


func test_nodes_missing_top_level_key_returns_empty() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({})
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'nodes' at <root>"])


func test_nodes_wrong_type_returns_empty() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"nodes": "not an array"})
	assert_that(nodes.size()).is_equal(0)
	assert_logged(
		["Required field 'nodes' has wrong type at <root>, expected 'Array' got 'String'"]
	)


func test_node_missing_body_is_skipped() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"nodes": [{"id": "start"}]})
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'body' at nodes[0]"])


func test_node_missing_id_is_skipped() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"nodes": [{"body": []}]})
	assert_that(nodes.size()).is_equal(0)
	assert_logged(["Missing required field 'id' at nodes[0]"])


func test_malformed_node_does_not_drop_valid_siblings() -> void:
	var data = {"nodes": [{"id": "broken"}, _node("ok", [])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes.size()).is_equal(1)
	assert_that(nodes[0].id).is_equal("ok")
	assert_logged(["Missing required field 'body' at nodes[0]"])


# =====================
# Statements
# =====================


func test_unknown_statement_type_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"type": "bogus"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Unknown statement type 'bogus' at nodes[0].body[0]"])


func test_statement_missing_type_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"text": "orphan"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Missing required field 'type' at nodes[0].body[0]"])


func test_narration_missing_text_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"type": "narration"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Missing required field 'text' at nodes[0].body[0]"])


func test_match_missing_cases_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"type": "match", "modifier": "first"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].body.size()).is_equal(0)
	assert_logged(["Missing required field 'cases' at nodes[0].body[0]"])


func test_match_unknown_modifier_is_skipped() -> void:
	var case_data = {"condition": true, "body": []}
	var match_data = {"type": "match", "modifier": "bogus", "cases": [case_data]}
	var data = {"nodes": [_node("start", [match_data])]}
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
	assert_logged(["Variable declaration at declarations[0] must be a Dictionary, got 2"])


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
	var data = {"nodes": [{"id": "start"}]}  # missing body
	WeavlyDeserializer.compile_nodes(data, "res://dialogue/build/scene2.json")
	assert_logged(["Missing required field 'body' at res://dialogue/build/scene2.json > nodes[0]"])


func test_declaration_error_includes_source_file_path() -> void:
	var data = {"declarations": [{"name": "score", "type": "number"}]}  # missing value
	WeavlyDeserializer.compile_variable_declarations(data, "res://dialogue/build/env.json")
	assert_logged(
		["Missing required field 'value' at res://dialogue/build/env.json > declarations[0]"]
	)
