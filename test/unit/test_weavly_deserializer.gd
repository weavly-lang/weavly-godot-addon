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
	var data: Dictionary = _build([_node("start", [statement.merged({"line": 2.0})])])
	var nodes: Array[WeavlyModel.WeavlyNode] = WeavlyDeserializer.compile_nodes(data)
	return nodes[0].body[0]


# =====================
# compile_nodes
# =====================


func test_compile_nodes_returns_correct_count() -> void:
	var data: Dictionary = _build([_node("a", []), _node("b", [])])
	var nodes: Array[WeavlyModel.WeavlyNode] = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes.size()).is_equal(2)


func test_compile_nodes_sets_id() -> void:
	var data: Dictionary = _build([_node("intro", [])])
	var nodes: Array[WeavlyModel.WeavlyNode] = WeavlyDeserializer.compile_nodes(data)
	assert_that(nodes[0].id).is_equal("intro")


# =====================
# Statements
# =====================


func test_narration_line() -> void:
	var stmt: WeavlyModel.Statement = _compile_single(
		{"type": "narration", "text": ["Hello world"]}
	)
	assert_object(stmt).is_instanceof(WeavlyModel.NarrationLine)
	assert_that((stmt as WeavlyModel.NarrationLine).segments).is_equal(["Hello world"])


func test_narration_line_with_an_interpolation() -> void:
	var stmt: WeavlyModel.Statement = _compile_single(
		{"type": "narration", "text": ["Hi ", {"variable": "name"}, "!", 5.0]}
	)
	var segments: Array = (stmt as WeavlyModel.NarrationLine).segments
	assert_int(segments.size()).is_equal(4)
	assert_that(segments[0]).is_equal("Hi ")
	assert_object(segments[1]).is_instanceof(WeavlyModel.Identifier)
	assert_that(segments[2]).is_equal("!")
	assert_object(segments[3]).is_instanceof(WeavlyModel.Number)


func test_narration_line_with_empty_text() -> void:
	var stmt: WeavlyModel.Statement = _compile_single({"type": "narration", "text": []})
	assert_that((stmt as WeavlyModel.NarrationLine).segments).is_empty()


func test_character_line() -> void:
	var stmt: WeavlyModel.Statement = _compile_single(
		{"type": "character", "name": "Alice", "name_is_id": false, "text": ["Hi there"]}
	)
	assert_object(stmt).is_instanceof(WeavlyModel.CharacterLine)
	var line: WeavlyModel.CharacterLine = stmt as WeavlyModel.CharacterLine
	assert_that(line.name).is_equal("Alice")
	assert_that(line.name_is_id).is_false()
	assert_that(line.segments).is_equal(["Hi there"])


func test_character_line_with_a_variable_name() -> void:
	var stmt: WeavlyModel.Statement = _compile_single(
		{"type": "character", "name": "speaker", "name_is_id": true, "text": ["Hi there"]}
	)
	var line: WeavlyModel.CharacterLine = stmt as WeavlyModel.CharacterLine
	assert_that(line.name).is_equal("speaker")
	assert_that(line.name_is_id).is_true()


func test_jump_statement() -> void:
	var stmt: WeavlyModel.Statement = _compile_single({"type": "jump", "id": "end"})
	assert_object(stmt).is_instanceof(WeavlyModel.JumpStatement)
	assert_that((stmt as WeavlyModel.JumpStatement).id).is_equal("end")


func test_inline_options_read_label_condition_and_body() -> void:
	var guarded: Dictionary = {
		"type": "inline",
		"line": 3.0,
		"meta":
		{
			"label": {"line": 3.0, "value": ["Pay ", {"variable": "gold"}]},
			"when": {"line": 3.0, "value": {"variable": "rich"}},
		},
		"body": [{"type": "finish", "line": 3.0}],
	}
	var plain: Dictionary = {
		"type": "inline",
		"line": 4.0,
		"meta": {"label": {"line": 4.0, "value": ["Leave"]}},
		"body": []
	}
	var stmt: WeavlyModel.Statement = _compile_single(
		{"type": "option", "items": [guarded, plain]}
	)
	var options: Array[WeavlyModel.Option] = (stmt as WeavlyModel.OptionBlock).options
	assert_that(options[0].segments[0]).is_equal("Pay ")
	assert_object(options[0].segments[1]).is_instanceof(WeavlyModel.Identifier)
	assert_object(options[0].condition).is_instanceof(WeavlyModel.Identifier)
	assert_object(options[0].body[0]).is_instanceof(WeavlyModel.FinishStatement)
	assert_that(options[1].segments).is_equal(["Leave"])
	assert_object(options[1].condition).is_instanceof(WeavlyModel.TrueExpression)
	assert_that(options[1].body).is_empty()


func test_finish_statement() -> void:
	var stmt: WeavlyModel.Statement = _compile_single({"type": "finish"})
	assert_object(stmt).is_instanceof(WeavlyModel.FinishStatement)


func test_command_statement() -> void:
	var data: Dictionary = {
		"type": "command", "id": "play_sound", "args": ["door", {"variable": "volume"}]
	}
	var stmt: WeavlyModel.Statement = _compile_single(data)
	assert_object(stmt).is_instanceof(WeavlyModel.CommandStatement)
	var cmd: WeavlyModel.CommandStatement = stmt as WeavlyModel.CommandStatement
	assert_that(cmd.id).is_equal("play_sound")
	assert_that(cmd.args.size()).is_equal(2)
	assert_object(cmd.args[0]).is_instanceof(WeavlyModel.StringLiteral)
	assert_object(cmd.args[1]).is_instanceof(WeavlyModel.Identifier)


func test_command_statement_without_arguments() -> void:
	var stmt: WeavlyModel.Statement = _compile_single(
		{"type": "command", "id": "fade_in", "args": []}
	)
	assert_that((stmt as WeavlyModel.CommandStatement).args).is_empty()


func test_set_statement() -> void:
	var stmt: WeavlyModel.Statement = _compile_single(
		{"type": "set", "id": "score", "expression": 10}
	)
	assert_object(stmt).is_instanceof(WeavlyModel.SetStatement)
	var set_stmt: WeavlyModel.SetStatement = stmt as WeavlyModel.SetStatement
	assert_that(set_stmt.id).is_equal("score")
	assert_object(set_stmt.expression).is_instanceof(WeavlyModel.Number)


# =====================
# Expressions
# =====================


func test_expression_number() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(42, "test")
	assert_object(expr).is_instanceof(WeavlyModel.Number)
	assert_that((expr as WeavlyModel.Number).value).is_equal(42.0)


func test_expression_string_literal() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression("hello", "test")
	assert_object(expr).is_instanceof(WeavlyModel.StringLiteral)
	assert_that((expr as WeavlyModel.StringLiteral).value).is_equal("hello")


func test_expression_true() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(true, "test")
	assert_object(expr).is_instanceof(WeavlyModel.TrueExpression)


func test_expression_false() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(false, "test")
	assert_object(expr).is_instanceof(WeavlyModel.FalseExpression)


func test_expression_identifier() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(
		{"variable": "score"}, "test"
	)
	assert_object(expr).is_instanceof(WeavlyModel.Identifier)
	assert_that((expr as WeavlyModel.Identifier).value).is_equal("score")


func test_expression_binary() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(
		{"op": "+", "left": 1, "right": 2}, "test"
	)
	assert_object(expr).is_instanceof(WeavlyModel.BinaryExpression)
	var bin: WeavlyModel.BinaryExpression = expr as WeavlyModel.BinaryExpression
	assert_that(bin.op).is_equal("+")
	assert_object(bin.left).is_instanceof(WeavlyModel.Number)
	assert_object(bin.right).is_instanceof(WeavlyModel.Number)


func test_expression_unary() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(
		{"op": "not", "expression": true}, "test"
	)
	assert_object(expr).is_instanceof(WeavlyModel.UnaryExpression)
	var unary: WeavlyModel.UnaryExpression = expr as WeavlyModel.UnaryExpression
	assert_that(unary.op).is_equal("not")
	assert_object(unary.expression).is_instanceof(WeavlyModel.TrueExpression)


# =====================
# Variable declarations
# =====================


func test_variable_declarations() -> void:
	var data: Dictionary = {
		"declarations":
		[
			{"name": "score", "type": "number", "value": 0.0},
			{"name": "greeting", "type": "string", "value": "hello"},
			{"name": "active", "type": "flag", "value": false},
		]
	}
	var vars: Array[WeavlyModel.Variable] = WeavlyDeserializer.compile_variable_declarations(data)
	assert_that(vars.size()).is_equal(3)
	assert_object(vars[0]).is_instanceof(WeavlyModel.NumberVariable)
	assert_object(vars[1]).is_instanceof(WeavlyModel.StringVariable)
	assert_object(vars[2]).is_instanceof(WeavlyModel.FlagVariable)


func test_node_pool_and_slot_variables_hold_names() -> void:
	var data: Dictionary = {
		"declarations":
		[
			{"name": "next", "type": "node", "value": "start"},
			{"name": "region", "type": "pool", "value": "city"},
			{"name": "partner", "type": "slot", "value": "bob"},
			{"name": "home", "type": "pool", "extern": true},
		]
	}
	var vars: Array[WeavlyModel.Variable] = WeavlyDeserializer.compile_variable_declarations(data)
	var types: Array[String] = []
	var values: Array[String] = []
	for variable: WeavlyModel.Variable in vars:
		assert_object(variable).is_instanceof(WeavlyModel.NameVariable)
		types.append(variable.get_type_name())
		values.append((variable as WeavlyModel.NameVariable).value)
	assert_array(types).is_equal(["node", "pool", "slot", "pool"])
	assert_array(values).is_equal(["start", "city", "bob", ""])
	assert_bool(vars[3].extern).is_true()


func test_number_variable_fields() -> void:
	var data: Dictionary = {
		"declarations":
		[
			{"name": "hp", "type": "number", "value": 100.0, "min": 0.0, "max": 100.0},
		]
	}
	var vars: Array[WeavlyModel.Variable] = WeavlyDeserializer.compile_variable_declarations(data)
	var v: WeavlyModel.NumberVariable = vars[0] as WeavlyModel.NumberVariable
	assert_that(v.id).is_equal("hp")
	assert_that(v.value).is_equal(100.0)
	assert_that(v.min).is_equal(0.0)
	assert_that(v.max).is_equal(100.0)


# =====================
# Calls
# =====================


func test_expression_call() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(
		{"call": "visited", "node": "shop"}, "test"
	)
	assert_object(expr).is_instanceof(WeavlyModel.Call)
	var visited: WeavlyModel.Call = expr as WeavlyModel.Call
	assert_that(visited.name).is_equal("visited")
	assert_that(visited.node_id).is_equal("shop")


func test_expression_call_with_unknown_function_is_rejected() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(
		{"call": "bogus", "node": "shop"}, "test"
	)
	assert_object(expr).is_null()
	assert_logged(["Unknown function 'bogus' at test"])


func test_expression_call_without_node_is_rejected() -> void:
	var expr: WeavlyModel.WeavlyExpression = WeavlyDeserializer.compile_expression(
		{"call": "visit_count"}, "test"
	)
	assert_object(expr).is_null()
	assert_logged(["Missing required field 'node' at test"])


func test_expression_call_with_arguments() -> void:
	var data: Dictionary = {"call": "max", "args": [1.0, {"variable": "hp"}]}
	var max_call: WeavlyModel.Call = (
		WeavlyDeserializer.compile_expression(data, "test") as WeavlyModel.Call
	)
	assert_that(max_call.name).is_equal("max")
	assert_that(max_call.args.size()).is_equal(2)
	assert_object(max_call.args[0]).is_instanceof(WeavlyModel.Number)
	assert_object(max_call.args[1]).is_instanceof(WeavlyModel.Identifier)


func test_expression_call_with_the_wrong_argument_count_is_rejected() -> void:
	var data: Dictionary = {"call": "min", "args": [1.0]}
	assert_object(WeavlyDeserializer.compile_expression(data, "test")).is_null()
	assert_logged(["min() takes at least 2 arguments, got 1 at test"])


func test_expression_call_with_a_failing_argument_is_rejected() -> void:
	var data: Dictionary = {"call": "abs", "args": [{"bogus": 1}]}
	assert_object(WeavlyDeserializer.compile_expression(data, "test")).is_null()
	assert_logged(["Unknown expression type at test.args[0]"])


func test_expression_call_without_args_is_rejected() -> void:
	assert_object(WeavlyDeserializer.compile_expression({"call": "round"}, "test")).is_null()
	assert_logged(["Missing required field 'args' at test"])


func test_extern_declaration() -> void:
	var data: Dictionary = {"declarations": [{"type": "string", "name": "title", "extern": true}]}
	var variables: Array[WeavlyModel.Variable] = WeavlyDeserializer.compile_variable_declarations(
		data
	)
	assert_object(variables[0]).is_instanceof(WeavlyModel.StringVariable)
	assert_that(variables[0].id).is_equal("title")
	assert_bool(variables[0].extern).is_true()


func test_extern_declarations_start_at_the_default_of_their_type() -> void:
	var data: Dictionary = {
		"declarations":
		[
			{"type": "number", "name": "gold", "extern": true},
			{"type": "string", "name": "title", "extern": true},
			{"type": "flag", "name": "brave", "extern": true},
		]
	}
	var variables: Array[WeavlyModel.Variable] = WeavlyDeserializer.compile_variable_declarations(
		data
	)
	var values: Array = variables.map(func(v: WeavlyModel.Variable) -> Variant: return v.value)
	assert_array(values).is_equal([0.0, "", false])


func test_extern_declaration_of_an_unknown_type_is_skipped() -> void:
	var data: Dictionary = {"declarations": [{"type": "list", "name": "items", "extern": true}]}
	assert_that(WeavlyDeserializer.compile_variable_declarations(data)).is_empty()
	assert_logged(["Unknown variable type at declarations[0]"])


func test_match_modifiers() -> void:
	var expected: Dictionary[String, WeavlyModel.MatchModifier] = {
		"first": WeavlyModel.MatchModifier.FIRST,
		"last": WeavlyModel.MatchModifier.LAST,
		"all": WeavlyModel.MatchModifier.ALL,
	}
	var case_data: Dictionary = {"line": 3.0, "condition": true, "body": []}
	for modifier: String in expected:
		var stmt: WeavlyModel.Statement = _compile_single(
			{"type": "match", "modifier": modifier, "cases": [case_data]}
		)
		assert_that((stmt as WeavlyModel.MatchBlock).modifier).is_equal(expected[modifier])


# =====================
# Locations
# =====================


func test_source_and_lines_are_read() -> void:
	var case_data: Dictionary = {"line": 4.0, "condition": true, "body": []}
	var data: Dictionary = {
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
	var option_block: Dictionary = {
		"type": "option",
		"line": 4.0,
		"items":
		[
			{
				"type": "inline",
				"line": 5.0,
				"meta": {"label": {"line": 5.0, "value": ["a"]}},
				"body": []
			}
		]
	}
	var random_block: Dictionary = {
		"type": "random",
		"line": 6.0,
		"cases": [{"line": 7.0, "condition": true, "weight": 1.0, "body": []}]
	}
	var data: Dictionary = _build([_node("start", [option_block, random_block])])
	var body: Array[WeavlyModel.Statement] = WeavlyDeserializer.compile_nodes(data)[0].body
	assert_int(body[0].options[0].line).is_equal(5)
	assert_int(body[1].cases[0].line).is_equal(7)


# =====================
# Meta
# =====================


func test_meta_is_read_with_its_lines() -> void:
	var node_data: Dictionary = _node("bob", [])
	node_data["meta"] = {
		"pool": {"line": 2.0, "value": ["city", "night"]},
		"slot": {"line": 3.0, "value": ["bob"]},
		"when": {"line": 4.0, "value": true},
		"priority": {"line": 5.0, "value": 2.0},
		"weight": {"line": 6.0, "value": {"variable": "w"}},
	}
	var meta: WeavlyModel.NodeMeta = WeavlyDeserializer.compile_nodes(_build([node_data]))[0].meta
	assert_array(meta.pools).is_equal(["city", "night"])
	assert_array(meta.slots).is_equal(["bob"])
	assert_object(meta.when.expression).is_instanceof(WeavlyModel.TrueExpression)
	assert_int(meta.when.line).is_equal(4)
	assert_that((meta.priority.expression as WeavlyModel.Number).value).is_equal(2.0)
	assert_object(meta.weight.expression).is_instanceof(WeavlyModel.Identifier)
	assert_int(meta.weight.line).is_equal(6)


func test_an_empty_meta_puts_the_node_in_no_pool() -> void:
	var node_data: Dictionary = _node("bob", [])
	node_data["meta"] = {}
	var meta: WeavlyModel.NodeMeta = WeavlyDeserializer.compile_nodes(_build([node_data]))[0].meta
	assert_array(meta.pools).is_empty()
	assert_object(meta.when).is_null()


func test_a_node_without_meta_has_none() -> void:
	assert_object(WeavlyDeserializer.compile_nodes(_build([_node("a", [])]))[0].meta).is_null()


func test_pool_names_are_read_from_env() -> void:
	var data: Dictionary = {"declarations": [], "pools": ["city", "night"], "slots": ["bob"]}
	assert_array(WeavlyDeserializer.compile_pool_names(data)).is_equal(["city", "night"])


func test_slot_names_are_read_from_env() -> void:
	var data: Dictionary = {"declarations": [], "pools": ["city"], "slots": ["bob", "ann"]}
	assert_array(WeavlyDeserializer.compile_slot_names(data)).is_equal(["bob", "ann"])


func test_draw_statement() -> void:
	var stmt: WeavlyModel.Statement = _compile_single({"type": "draw", "pools": ["city", "night"]})
	assert_object(stmt).is_instanceof(WeavlyModel.DrawStatement)
	assert_array((stmt as WeavlyModel.DrawStatement).pools).is_equal(["city", "night"])
