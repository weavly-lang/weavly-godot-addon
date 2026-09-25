# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# Smoke tests for WeavlyDeserializer (the JSON-to-model deserializer).
# Pure input/output — no scene or services required.

# =====================
# Helpers
# =====================


func _build(nodes: Array) -> Dictionary:
	return {"source": "story.wvl", "nodes": nodes}


func _node(id: String, body: Array) -> Dictionary:
	return {"id": id, "line": 1.0, "body": body}


func _compile_single(statement: Dictionary) -> WeavlyModel.Statement:
	var data = _build([_node("start", [statement.merged({"line": 2.0})])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	return nodes[0].body[0]


# =====================
# compile_nodes
# =====================


func test_compile_nodes_returns_correct_count() -> void:
	var data = _build([_node("a", []), _node("b", [])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes.size()).is_equal(2)


func test_compile_nodes_sets_id() -> void:
	var data = _build([_node("intro", [])])
	var nodes = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].id).is_equal("intro")


# =====================
# Statements
# =====================


func test_narration_line() -> void:
	var stmt = _compile_single({"type": "narration", "text": ["Hello world"]})
	assert_object(stmt).is_instanceof(WeavlyModel.NarrationLine)
	assert_that((stmt as WeavlyModel.NarrationLine).segments).is_equal(["Hello world"])


func test_narration_line_with_an_interpolation() -> void:
	var stmt = _compile_single(
		{"type": "narration", "text": ["Hi ", {"variable": "name"}, "!", 5.0]}
	)
	var segments: Array = (stmt as WeavlyModel.NarrationLine).segments
	assert_int(segments.size()).is_equal(4)
	assert_that(segments[0]).is_equal("Hi ")
	assert_object(segments[1]).is_instanceof(WeavlyModel.Identifier)
	assert_that(segments[2]).is_equal("!")
	assert_object(segments[3]).is_instanceof(WeavlyModel.Number)


func test_narration_line_with_empty_text() -> void:
	var stmt = _compile_single({"type": "narration", "text": []})
	assert_that((stmt as WeavlyModel.NarrationLine).segments).is_empty()


func test_character_line() -> void:
	var stmt = _compile_single(
		{"type": "character", "name": "Alice", "name_is_id": false, "text": ["Hi there"]}
	)
	assert_object(stmt).is_instanceof(WeavlyModel.CharacterLine)
	var line := stmt as WeavlyModel.CharacterLine
	assert_that(line.name).is_equal("Alice")
	assert_that(line.name_is_id).is_false()
	assert_that(line.segments).is_equal(["Hi there"])


func test_character_line_with_a_variable_name() -> void:
	var stmt = _compile_single(
		{"type": "character", "name": "speaker", "name_is_id": true, "text": ["Hi there"]}
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
	var data = {"type": "command", "id": "play_sound", "args": ["door", {"variable": "volume"}]}
	var stmt = _compile_single(data)
	assert_object(stmt).is_instanceof(WeavlyModel.CommandStatement)
	var cmd := stmt as WeavlyModel.CommandStatement
	assert_that(cmd.id).is_equal("play_sound")
	assert_that(cmd.args.size()).is_equal(2)
	assert_object(cmd.args[0]).is_instanceof(WeavlyModel.StringLiteral)
	assert_object(cmd.args[1]).is_instanceof(WeavlyModel.Identifier)


func test_command_statement_without_arguments() -> void:
	var stmt = _compile_single({"type": "command", "id": "fade_in", "args": []})
	assert_that((stmt as WeavlyModel.CommandStatement).args).is_empty()


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
	assert_that((expr as WeavlyModel.Identifier).value).is_equal("score")


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
	assert_that(v.id).is_equal("hp")
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


func test_expression_call_with_arguments() -> void:
	var data = {"call": "max", "args": [1.0, {"variable": "hp"}]}
	var call := WeavlyDeserializer.compile_expression(data, "test") as WeavlyModel.Call
	assert_that(call.name).is_equal("max")
	assert_that(call.args.size()).is_equal(2)
	assert_object(call.args[0]).is_instanceof(WeavlyModel.Number)
	assert_object(call.args[1]).is_instanceof(WeavlyModel.Identifier)


func test_expression_call_with_the_wrong_argument_count_is_rejected() -> void:
	var data = {"call": "min", "args": [1.0]}
	assert_object(WeavlyDeserializer.compile_expression(data, "test")).is_null()
	assert_logged(["min() takes at least 2 arguments, got 1 at test"])


func test_expression_call_with_a_failing_argument_is_rejected() -> void:
	var data = {"call": "abs", "args": [{"bogus": 1}]}
	assert_object(WeavlyDeserializer.compile_expression(data, "test")).is_null()
	assert_logged(["Unknown expression type at test.args[0]"])


func test_expression_call_without_args_is_rejected() -> void:
	assert_object(WeavlyDeserializer.compile_expression({"call": "round"}, "test")).is_null()
	assert_logged(["Missing required field 'args' at test"])


func test_extern_declaration() -> void:
	var data = {"declarations": [{"type": "string", "name": "title", "extern": true}]}
	var variables = WeavlyDeserializer.compile_variable_declarations(data)
	assert_object(variables[0]).is_instanceof(WeavlyModel.StringVariable)
	assert_that(variables[0].id).is_equal("title")
	assert_bool(variables[0].extern).is_true()


func test_extern_declaration_of_an_unknown_type_is_skipped() -> void:
	var data = {"declarations": [{"type": "list", "name": "items", "extern": true}]}
	assert_that(WeavlyDeserializer.compile_variable_declarations(data)).is_empty()
	assert_logged(["Unknown variable type at declarations[0]"])


# =====================
# Locations
# =====================


func test_source_and_lines_are_read() -> void:
	var case_data = {"line": 4.0, "condition": true, "body": []}
	var data = {
		"source": "chapter/story.wvl",
		"nodes":
		[
			{
				"id": "start",
				"line": 1.0,
				"body":
				[
					{"type": "narration", "line": 2.0, "text": ["Hi"]},
					{"type": "match", "line": 3.0, "modifier": "first", "cases": [case_data]},
				]
			}
		]
	}
	var node: WeavlyModel.WeavlyNode = WeavlyDeserializer.compile_nodes(data, "build/x.json")[0]
	assert_that(node.source).is_equal("chapter/story.wvl")
	assert_int(node.line).is_equal(1)
	assert_int(node.body[0].line).is_equal(2)
	assert_int(node.body[1].line).is_equal(3)
	assert_int(node.body[1].cases[0].line).is_equal(4)


func test_option_and_random_case_lines_are_read() -> void:
	var option_block = {
		"type": "option",
		"line": 4.0,
		"items": [{"line": 5.0, "condition": true, "text": ["a"], "body": [], "hint": false}]
	}
	var random_block = {
		"type": "random",
		"line": 6.0,
		"cases": [{"line": 7.0, "condition": true, "weight": 1.0, "body": []}]
	}
	var data = _build([_node("start", [option_block, random_block])])
	var body = WeavlyDeserializer.compile_nodes(data)[0].body
	assert_int(body[0].options[0].line).is_equal(5)
	assert_int(body[1].cases[0].line).is_equal(7)
