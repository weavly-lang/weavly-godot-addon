# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# Smoke tests for WeavlyDeserializer (the JSON-to-model deserializer).
# Pure input/output — no scene or services required.

# =====================
# Helpers
# =====================


func _node(id: String, body: Array) -> Dictionary:
	return {"id": id, "body": body}


func _compile_single(statement: Dictionary) -> WeavlyModel.Statement:
	var data = {"nodes": [_node("start", [statement])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	return nodes[0].body[0]


# =====================
# compile_nodes
# =====================


func test_compile_nodes_returns_correct_count() -> void:
	var data = {
		"nodes":
		[
			_node("a", []),
			_node("b", []),
		]
	}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes.size()).is_equal(2)


func test_compile_nodes_sets_id() -> void:
	var data = {"nodes": [_node("intro", [])]}
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].id).is_equal("intro")


# =====================
# Statements
# =====================


func test_narration_line() -> void:
	var stmt = _compile_single({"type": "narration", "text": "Hello world"})
	assert_object(stmt).is_instanceof(WeavlyModel.NarrationLine)
	assert_that((stmt as WeavlyModel.NarrationLine).text).is_equal("Hello world")


func test_character_line() -> void:
	var stmt = _compile_single(
		{"type": "character", "name": "Alice", "name_is_id": false, "text": "Hi there"}
	)
	assert_object(stmt).is_instanceof(WeavlyModel.CharacterLine)
	var line := stmt as WeavlyModel.CharacterLine
	assert_that(line.name).is_equal("Alice")
	assert_that(line.name_is_id).is_false()
	assert_that(line.text).is_equal("Hi there")


func test_character_line_with_a_variable_name() -> void:
	var stmt = _compile_single(
		{"type": "character", "name": "speaker", "name_is_id": true, "text": "Hi there"}
	)
	var line := stmt as WeavlyModel.CharacterLine
	assert_that(line.name).is_equal("speaker")
	assert_that(line.name_is_id).is_true()


func test_goto_statement() -> void:
	var stmt = _compile_single({"type": "goto", "id": "end"})
	assert_object(stmt).is_instanceof(WeavlyModel.GotoStatement)
	assert_that((stmt as WeavlyModel.GotoStatement).id).is_equal("end")


func test_finish_statement() -> void:
	var stmt = _compile_single({"type": "finish"})
	assert_object(stmt).is_instanceof(WeavlyModel.FinishStatement)


func test_command_statement() -> void:
	var stmt = _compile_single({"type": "command", "id": "shake_cam", "text": "strong"})
	assert_object(stmt).is_instanceof(WeavlyModel.CommandStatement)
	var cmd := stmt as WeavlyModel.CommandStatement
	assert_that(cmd.id).is_equal("shake_cam")
	assert_that(cmd.text).is_equal("strong")


func test_set_statement() -> void:
	var stmt = _compile_single({"type": "set", "id": "score", "expression": 10})
	assert_object(stmt).is_instanceof(WeavlyModel.SetStatement)
	var set_stmt := stmt as WeavlyModel.SetStatement
	assert_that(set_stmt.id).is_equal("score")
	assert_object(set_stmt.expression).is_instanceof(WeavlyModel.Number)


# =====================
# Expressions
# =====================


func test_expression_number() -> void:
	var expr = WeavlyDeserializer.compile_expression(42, "test")
	assert_object(expr).is_instanceof(WeavlyModel.Number)
	assert_that((expr as WeavlyModel.Number).value).is_equal(42.0)


func test_expression_string_literal() -> void:
	var expr = WeavlyDeserializer.compile_expression("hello", "test")
	assert_object(expr).is_instanceof(WeavlyModel.StringLiteral)
	assert_that((expr as WeavlyModel.StringLiteral).value).is_equal("hello")


func test_expression_true() -> void:
	var expr = WeavlyDeserializer.compile_expression(true, "test")
	assert_object(expr).is_instanceof(WeavlyModel.TrueExpression)


func test_expression_false() -> void:
	var expr = WeavlyDeserializer.compile_expression(false, "test")
	assert_object(expr).is_instanceof(WeavlyModel.FalseExpression)


func test_expression_identifier() -> void:
	var expr = WeavlyDeserializer.compile_expression({"variable": "score"}, "test")
	assert_object(expr).is_instanceof(WeavlyModel.Identifier)
	assert_that((expr as WeavlyModel.Identifier).value).is_equal(&"score")


func test_expression_binary() -> void:
	var expr = WeavlyDeserializer.compile_expression({"op": "+", "left": 1, "right": 2}, "test")
	assert_object(expr).is_instanceof(WeavlyModel.BinaryExpression)
	var bin := expr as WeavlyModel.BinaryExpression
	assert_that(bin.op).is_equal("+")
	assert_object(bin.left).is_instanceof(WeavlyModel.Number)
	assert_object(bin.right).is_instanceof(WeavlyModel.Number)


func test_expression_unary() -> void:
	var expr = WeavlyDeserializer.compile_expression({"op": "not", "expression": true}, "test")
	assert_object(expr).is_instanceof(WeavlyModel.UnaryExpression)
	var unary := expr as WeavlyModel.UnaryExpression
	assert_that(unary.op).is_equal("not")
	assert_object(unary.expression).is_instanceof(WeavlyModel.TrueExpression)


# =====================
# Variable declarations
# =====================


func test_variable_declarations() -> void:
	var data = {
		"declarations":
		[
			{"name": "score", "type": "number", "value": 0.0},
			{"name": "greeting", "type": "string", "value": "hello"},
			{"name": "active", "type": "flag", "value": false},
		]
	}
	var vars = WeavlyDeserializer.compile_variable_declarations(data)
	assert_that(vars.size()).is_equal(3)
	assert_object(vars[0]).is_instanceof(WeavlyModel.NumberVariable)
	assert_object(vars[1]).is_instanceof(WeavlyModel.StringVariable)
	assert_object(vars[2]).is_instanceof(WeavlyModel.FlagVariable)


func test_number_variable_fields() -> void:
	var data = {
		"declarations":
		[
			{"name": "hp", "type": "number", "value": 100.0, "min": 0.0, "max": 100.0},
		]
	}
	var vars = WeavlyDeserializer.compile_variable_declarations(data)
	var v := vars[0] as WeavlyModel.NumberVariable
	assert_that(v.id).is_equal(&"hp")
	assert_that(v.value).is_equal(100.0)
	assert_that(v.min).is_equal(0.0)
	assert_that(v.max).is_equal(100.0)


# =====================
# Calls
# =====================


func test_expression_call() -> void:
	var expr = WeavlyDeserializer.compile_expression({"call": "visited", "node": "shop"}, "test")
	assert_object(expr).is_instanceof(WeavlyModel.Call)
	var call := expr as WeavlyModel.Call
	assert_that(call.name).is_equal("visited")
	assert_that(call.node_id).is_equal("shop")


func test_expression_call_with_unknown_function_is_rejected() -> void:
	var expr = WeavlyDeserializer.compile_expression({"call": "bogus", "node": "shop"}, "test")
	assert_object(expr).is_null()
	assert_logged(["Unknown function 'bogus' at test"])


func test_expression_call_without_node_is_rejected() -> void:
	var expr = WeavlyDeserializer.compile_expression({"call": "visit_count"}, "test")
	assert_object(expr).is_null()
	assert_logged(["Missing required field 'node' at test"])
