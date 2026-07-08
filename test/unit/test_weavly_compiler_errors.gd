extends GutTest

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
	assert_eq(nodes.size(), 0)
	assert_push_error(1)


func test_nodes_wrong_type_returns_empty() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"nodes": "not an array"})
	assert_eq(nodes.size(), 0)
	assert_push_error(1)


func test_node_missing_body_is_skipped() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"nodes": [{"id": "start"}]})
	assert_eq(nodes.size(), 0)
	assert_push_error(1)


func test_node_missing_id_is_skipped() -> void:
	var nodes = WeavlyDeserializer.compile_nodes({"nodes": [{"body": []}]})
	assert_eq(nodes.size(), 0)
	assert_push_error(1)


func test_malformed_node_does_not_drop_valid_siblings() -> void:
	var data = {"nodes": [{"id": "broken"}, _node("ok", [])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_eq(nodes.size(), 1)
	assert_eq(nodes[0].id, "ok")
	assert_push_error(1)


# =====================
# Statements
# =====================


func test_unknown_statement_type_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"type": "bogus"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_eq(nodes[0].body.size(), 0)
	assert_push_error(1)


func test_statement_missing_type_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"text": "orphan"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_eq(nodes[0].body.size(), 0)
	assert_push_error(1)


func test_narration_missing_text_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"type": "narration"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_eq(nodes[0].body.size(), 0)
	assert_push_error(1)


func test_match_missing_cases_is_skipped() -> void:
	var data = {"nodes": [_node("start", [{"type": "match", "modifier": "first"}])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_eq(nodes[0].body.size(), 0)
	assert_push_error(1)


# =====================
# Variable declarations
# =====================


func test_variable_missing_value_is_skipped() -> void:
	var data = {"declarations": [{"name": "score", "type": "number"}]}
	var vars = WeavlyDeserializer.compile_variable_declarations(data)
	assert_eq(vars.size(), 0)
	assert_push_error(1)


func test_variable_declaration_non_dictionary_is_skipped() -> void:
	var vars = WeavlyDeserializer.compile_variable_declarations({"declarations": [42]})
	assert_eq(vars.size(), 0)
	assert_push_error(1)


func test_declarations_wrong_type_returns_empty() -> void:
	var vars = WeavlyDeserializer.compile_variable_declarations({"declarations": "nope"})
	assert_eq(vars.size(), 0)
	assert_push_error(1)


# =====================
# Source file attribution
# =====================


func test_node_error_includes_source_file_path() -> void:
	var data = {"nodes": [{"id": "start"}]}  # missing body
	WeavlyDeserializer.compile_nodes(data, "res://dialog/build/scene2.json")
	assert_push_error("scene2.json")


func test_declaration_error_includes_source_file_path() -> void:
	var data = {"declarations": [{"name": "score", "type": "number"}]}  # missing value
	WeavlyDeserializer.compile_variable_declarations(data, "res://dialog/build/env.json")
	assert_push_error("env.json")
