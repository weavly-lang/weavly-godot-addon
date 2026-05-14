extends GutTest

# Smoke tests for WeavlyCompiler (the JSON-to-model deserializer).
# Pure input/output — no scene or services required.

# =====================
# Helpers
# =====================


func _node(id: String, body: Array) -> Dictionary:
	return {"id": id, "body": body}


func _compile_single(statement: Dictionary) -> WeavlyModel.Statement:
	var data = {"nodes": [_node("start", [statement])]}
	var nodes = WeavlyCompiler.compile_nodes(data)
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
	var nodes = WeavlyCompiler.compile_nodes(data)
	assert_eq(nodes.size(), 2)


func test_compile_nodes_sets_id() -> void:
	var data = {"nodes": [_node("intro", [])]}
	var nodes = WeavlyCompiler.compile_nodes(data)
	assert_eq(nodes[0].id, "intro")


# =====================
# Statements
# =====================


func test_narration_line() -> void:
	var stmt = _compile_single({"type": "narration", "text": "Hello world"})
	assert_is(stmt, WeavlyModel.NarrationLine)
	assert_eq((stmt as WeavlyModel.NarrationLine).text, "Hello world")


func test_character_line() -> void:
	var stmt = _compile_single(
		{"type": "character", "name": "Alice", "id": false, "text": "Hi there"}
	)
	assert_is(stmt, WeavlyModel.CharacterLine)
	var line := stmt as WeavlyModel.CharacterLine
	assert_eq(line.name, "Alice")
	assert_eq(line.text, "Hi there")


func test_goto_statement() -> void:
	var stmt = _compile_single({"type": "goto", "id": "end"})
	assert_is(stmt, WeavlyModel.GotoStatement)
	assert_eq((stmt as WeavlyModel.GotoStatement).id, "end")


func test_finish_statement() -> void:
	var stmt = _compile_single({"type": "finish"})
	assert_is(stmt, WeavlyModel.FinishStatement)


func test_command_statement() -> void:
	var stmt = _compile_single({"type": "command", "id": "shake_cam", "text": "strong"})
	assert_is(stmt, WeavlyModel.CommandStatement)
	var cmd := stmt as WeavlyModel.CommandStatement
	assert_eq(cmd.id, "shake_cam")
	assert_eq(cmd.text, "strong")


func test_set_statement() -> void:
	var stmt = _compile_single({"type": "set", "id": "score", "expression": 10})
	assert_is(stmt, WeavlyModel.SetStatement)
	var set_stmt := stmt as WeavlyModel.SetStatement
	assert_eq(set_stmt.id, "score")
	assert_is(set_stmt.expression, WeavlyModel.Number)


# =====================
# Expressions
# =====================


func test_expression_number() -> void:
	var expr = WeavlyCompiler.compile_expression(42, "test")
	assert_is(expr, WeavlyModel.Number)
	assert_eq((expr as WeavlyModel.Number).value, 42.0)


func test_expression_string_literal() -> void:
	var expr = WeavlyCompiler.compile_expression("hello", "test")
	assert_is(expr, WeavlyModel.StringLiteral)
	assert_eq((expr as WeavlyModel.StringLiteral).value, "hello")


func test_expression_true() -> void:
	var expr = WeavlyCompiler.compile_expression(true, "test")
	assert_is(expr, WeavlyModel.TrueExpression)


func test_expression_false() -> void:
	var expr = WeavlyCompiler.compile_expression(false, "test")
	assert_is(expr, WeavlyModel.FalseExpression)


func test_expression_identifier() -> void:
	var expr = WeavlyCompiler.compile_expression({"variable": "score"}, "test")
	assert_is(expr, WeavlyModel.Identifier)
	assert_eq((expr as WeavlyModel.Identifier).value, &"score")


func test_expression_binary() -> void:
	var expr = WeavlyCompiler.compile_expression({"op": "+", "left": 1, "right": 2}, "test")
	assert_is(expr, WeavlyModel.BinaryExpression)
	var bin := expr as WeavlyModel.BinaryExpression
	assert_eq(bin.op, "+")
	assert_is(bin.left, WeavlyModel.Number)
	assert_is(bin.right, WeavlyModel.Number)


func test_expression_unary() -> void:
	var expr = WeavlyCompiler.compile_expression({"op": "not", "expression": true}, "test")
	assert_is(expr, WeavlyModel.UnaryExpression)
	var unary := expr as WeavlyModel.UnaryExpression
	assert_eq(unary.op, "not")
	assert_is(unary.expression, WeavlyModel.TrueExpression)


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
	var vars = WeavlyCompiler.compile_variable_declarations(data)
	assert_eq(vars.size(), 3)
	assert_is(vars[0], WeavlyModel.NumberVariable)
	assert_is(vars[1], WeavlyModel.StringVariable)
	assert_is(vars[2], WeavlyModel.FlagVariable)


func test_number_variable_fields() -> void:
	var data = {
		"declarations":
		[
			{"name": "hp", "type": "number", "value": 100.0, "min": 0.0, "max": 100.0},
		]
	}
	var vars = WeavlyCompiler.compile_variable_declarations(data)
	var v := vars[0] as WeavlyModel.NumberVariable
	assert_eq(v.id, &"hp")
	assert_eq(v.value, 100.0)
	assert_eq(v.min, 0.0)
	assert_eq(v.max, 100.0)
