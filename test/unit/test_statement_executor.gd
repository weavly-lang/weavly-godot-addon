# gdlint:ignore = max-public-methods

extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

# =====================
# Spy services
# =====================


class _SpyLineService:
	extends WeavlyLineService
	var narration_calls: Array[WeavlyModel.NarrationLine] = []
	var character_calls: Array[WeavlyModel.CharacterLine] = []

	func execute_narration_line(line: WeavlyModel.NarrationLine) -> void:
		narration_calls.append(line)

	func execute_character_line(line: WeavlyModel.CharacterLine) -> void:
		character_calls.append(line)


class _SpyCommandService:
	extends WeavlyCommandService
	var command_calls: Array[WeavlyModel.CommandStatement] = []

	func register_command(_name: String, _callable: Callable) -> void:
		pass

	func execute_command(command: WeavlyModel.CommandStatement) -> void:
		command_calls.append(command)

	func get_unregistered() -> Array[String]:
		return []


class _SpyOptionService:
	extends WeavlyOptionService
	var add_options_calls: Array[Array] = []

	func has_options() -> bool:
		return false

	func get_options() -> Array[WeavlyModel.Option]:
		return []

	func add_options(options: Array[WeavlyModel.Option]) -> void:
		add_options_calls.append(options)

	func clear_options() -> void:
		pass


class _SpyStatementService:
	extends WeavlyStatementService
	var add_statements_calls: Array[Array] = []
	var add_statement_groups_calls: Array[Array] = []

	func add_statements(statements: Array[WeavlyModel.Statement]) -> void:
		add_statements_calls.append(statements)

	func add_node_statements(_statements: Array[WeavlyModel.Statement]) -> void:
		pass

	func add_statement_groups(groups: Array[Array]) -> void:
		add_statement_groups_calls.append(groups)

	func pause() -> void:
		pass

	func resume() -> void:
		pass

	func is_paused() -> bool:
		return false

	func clear_statements() -> void:
		pass

	func advance_statements() -> void:
		pass


# =====================
# Setup
# =====================

var _engine: WeavlyEngine
var _line: _SpyLineService
var _command: _SpyCommandService
var _option: _SpyOptionService
var _statement: _SpyStatementService


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	_line = _SpyLineService.new()
	_line.initialize(_engine)
	_engine.line_service = _line
	_command = _SpyCommandService.new()
	_command.initialize(_engine)
	_engine.command_service = _command
	_option = _SpyOptionService.new()
	_option.initialize(_engine)
	_engine.option_service = _option
	_statement = _SpyStatementService.new()
	_statement.initialize(_engine)
	_engine.statement_service = _statement


# =====================
# Helpers
# =====================


func _body(tag: String = "") -> Array[WeavlyModel.Statement]:
	# Use a NarrationLine as a sentinel so we can identify which body was passed.
	var body: Array[WeavlyModel.Statement] = []
	body.append(WeavlyModel.NarrationLine.new([tag]))
	return body


func _bool_expr(v: bool) -> WeavlyModel.WeavlyExpression:
	if v:
		return WeavlyModel.TrueExpression.new()
	return WeavlyModel.FalseExpression.new()


class _UnknownStatement:
	extends WeavlyModel.Statement


func test_an_unknown_statement_is_reported() -> void:
	WeavlyStatementExecutor.execute_statement(_UnknownStatement.new(), _engine)
	assert_logged(["Can't execute an unknown statement."])


# =====================
# Delegation: narration / character
# =====================


func test_narration_line_delegates_to_line_service() -> void:
	var line: WeavlyModel.NarrationLine = WeavlyModel.NarrationLine.new(["hello"])
	WeavlyStatementExecutor.execute_statement(line, _engine)
	assert_that(_line.narration_calls.size()).is_equal(1)
	assert_that(_line.narration_calls[0]).is_same(line)


func test_character_line_delegates_to_line_service() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("Alice", false, ["hi"])
	WeavlyStatementExecutor.execute_statement(line, _engine)
	assert_that(_line.character_calls.size()).is_equal(1)
	assert_that(_line.character_calls[0]).is_same(line)


# =====================
# Delegation: command
# =====================


func test_command_statement_delegates_a_filled_copy_to_command_service() -> void:
	var command: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new("cmd")
	command.line = 4
	WeavlyStatementExecutor.execute_statement(command, _engine)
	assert_that(_command.command_calls.size()).is_equal(1)
	assert_that(_command.command_calls[0]).is_not_same(command)
	assert_that(_command.command_calls[0].id).is_equal("cmd")
	assert_int(_command.command_calls[0].line).is_equal(4)
	assert_that(_command.command_calls[0].values).is_empty()


func test_command_arguments_are_evaluated_when_the_command_runs() -> void:
	declare(_engine, WeavlyModel.NumberVariable.new("volume", 0.8, null, null))
	var args: Array[WeavlyModel.WeavlyExpression] = [
		WeavlyModel.StringLiteral.new("door"),
		WeavlyModel.BinaryExpression.new(
			"*", WeavlyModel.Identifier.new("volume"), WeavlyModel.Number.new(0.5)
		),
		WeavlyModel.Call.new(
			"max", "", [WeavlyModel.Number.new(1.0), WeavlyModel.Number.new(2.0)]
		),
	]
	var command: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new(
		"play_sound", args
	)
	WeavlyStatementExecutor.execute_statement(command, _engine)
	_engine.set_variable("volume", 0.2)
	WeavlyStatementExecutor.execute_statement(command, _engine)
	assert_that(_command.command_calls[0].values).is_equal(["door", 0.4, 2.0])
	assert_that(_command.command_calls[1].values).is_equal(["door", 0.1, 2.0])
	assert_that(command.values).is_empty()


func test_command_with_a_failing_argument_is_skipped() -> void:
	var args: Array[WeavlyModel.WeavlyExpression] = [WeavlyModel.Identifier.new("missing")]
	var command: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new(
		"play_sound", args
	)
	WeavlyStatementExecutor.execute_statement(command, _engine)
	assert_logged(["Variable 'missing' isn't defined."])
	assert_that(_command.command_calls).is_empty()


# =====================
# Delegation: jump
# =====================


func test_jump_statement_delegates_to_engine_enter_node() -> void:
	var jump: WeavlyModel.JumpStatement = WeavlyModel.JumpStatement.new("target_node")
	WeavlyStatementExecutor.execute_statement(jump, _engine)
	assert_that(_engine.last_entered_node).is_equal("target_node")


func test_detour_statement_delegates_to_engine_detour() -> void:
	var detour: WeavlyModel.DetourStatement = WeavlyModel.DetourStatement.new("aside")
	WeavlyStatementExecutor.execute_statement(detour, _engine)
	assert_that(_engine.last_detoured_node).is_equal("aside")
	assert_that(_engine.last_entered_node).is_empty()


# =====================
# Delegation: finish
# =====================


func test_finish_statement_delegates_to_engine_finish() -> void:
	var finish: WeavlyModel.FinishStatement = WeavlyModel.FinishStatement.new()
	WeavlyStatementExecutor.execute_statement(finish, _engine)
	assert_bool(_engine.did_finish).is_true()


# =====================
# execute_match_block — FIRST
# =====================


func test_match_first_picks_first_matching_case() -> void:
	var first: Array[WeavlyModel.Statement] = _body("first")
	var second: Array[WeavlyModel.Statement] = _body("second")
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("skip")),
		WeavlyModel.WhenCase.new(_bool_expr(true), first),
		WeavlyModel.WhenCase.new(_bool_expr(true), second),
	]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.FIRST, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(1)
	assert_that(_statement.add_statements_calls[0]).is_same(first)


func test_match_first_no_match_does_nothing() -> void:
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("a")),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("b")),
	]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.FIRST, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(0)


# =====================
# execute_match_block — LAST
# =====================


func test_match_last_picks_last_matching_case() -> void:
	var first: Array[WeavlyModel.Statement] = _body("first")
	var last: Array[WeavlyModel.Statement] = _body("last")
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(true), first),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("skip")),
		WeavlyModel.WhenCase.new(_bool_expr(true), last),
	]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.LAST, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(1)
	assert_that(_statement.add_statements_calls[0]).is_same(last)


func test_match_last_does_not_reorder_the_blocks_cases() -> void:
	var first: WeavlyModel.WhenCase = WeavlyModel.WhenCase.new(_bool_expr(true), _body("first"))
	var last: WeavlyModel.WhenCase = WeavlyModel.WhenCase.new(_bool_expr(true), _body("last"))
	var cases: Array[WeavlyModel.WhenCase] = [first, last]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.LAST, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_that(block.cases[0]).is_same(first)
	assert_that(block.cases[1]).is_same(last)


func test_match_block_can_run_twice_with_the_same_result() -> void:
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(true), _body("first")),
		WeavlyModel.WhenCase.new(_bool_expr(true), _body("last")),
	]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.LAST, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_that(_statement.add_statements_calls[0]).is_same(_statement.add_statements_calls[1])


# =====================
# execute_match_block — ALL
# =====================


func test_match_all_collects_matching_cases_as_groups() -> void:
	var a: Array[WeavlyModel.Statement] = _body("a")
	var b: Array[WeavlyModel.Statement] = _body("b")
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(true), a),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("skip")),
		WeavlyModel.WhenCase.new(_bool_expr(true), b),
	]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.ALL, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_that(_statement.add_statement_groups_calls.size()).is_equal(1)
	var groups: Array = _statement.add_statement_groups_calls[0]
	assert_that(groups.size()).is_equal(2)
	assert_that(groups[0]).is_same(a)
	assert_that(groups[1]).is_same(b)


func test_match_all_with_no_matches_passes_empty_groups() -> void:
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("a")),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("b")),
	]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.ALL, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_that(_statement.add_statement_groups_calls.size()).is_equal(1)
	assert_that((_statement.add_statement_groups_calls[0] as Array).size()).is_equal(0)


# =====================
# execute_option_block
# =====================


func _inline_item(condition: bool, text: String) -> WeavlyModel.InlineOptionItem:
	return WeavlyModel.InlineOptionItem.new(_bool_expr(condition), [text], _body(text))


func test_option_block_offers_the_inline_options_whose_condition_holds() -> void:
	var keep_a: WeavlyModel.InlineOptionItem = _inline_item(true, "a")
	var keep_c: WeavlyModel.InlineOptionItem = _inline_item(true, "c")
	var items: Array[WeavlyModel.OptionItem] = [keep_a, _inline_item(false, "b"), keep_c]
	WeavlyStatementExecutor.execute_option_block(WeavlyModel.OptionBlock.new(items), _engine)
	assert_that(_option.add_options_calls.size()).is_equal(1)
	var passed: Array = _option.add_options_calls[0]
	(
		assert_array(passed.map(func(option: WeavlyModel.Option) -> String: return option.text))
		. is_equal(["a", "c"])
	)
	assert_that(passed[0].item).is_same(keep_a)
	assert_that(passed[1].item).is_same(keep_c)


func test_option_block_with_no_passing_options_does_not_add_options() -> void:
	var items: Array[WeavlyModel.OptionItem] = [_inline_item(false, "a")]
	WeavlyStatementExecutor.execute_option_block(WeavlyModel.OptionBlock.new(items), _engine)
	assert_that(_option.add_options_calls).is_empty()


func test_option_block_without_options_does_not_add_options() -> void:
	var items: Array[WeavlyModel.OptionItem] = []
	WeavlyStatementExecutor.execute_option_block(WeavlyModel.OptionBlock.new(items), _engine)
	assert_that(_option.add_options_calls).is_empty()


# =====================
# execute_random_block
# =====================


func _weight(v: float) -> WeavlyModel.Number:
	return WeavlyModel.Number.new(v)


# Seeds the engine so its next roll lands in (low, high].
func _roll_between(low: float, high: float) -> void:
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in range(1, 1000):
		probe.seed = seed_value
		var roll: float = probe.randf()
		if roll > low and roll <= high:
			_engine.rng.seed = seed_value
			return
	fail("No seed rolls between %s and %s." % [low, high])


func test_random_block_picks_case_based_on_rng() -> void:
	# Weights: a=10, b=30, c=60. Total=100, so a roll in (0, 0.1] falls in a's bucket.
	var a: Array[WeavlyModel.Statement] = _body("a")
	var b: Array[WeavlyModel.Statement] = _body("b")
	var c: Array[WeavlyModel.Statement] = _body("c")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), a),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(30.0), b),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(60.0), c),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	_roll_between(0.0, 0.1)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(1)
	assert_that(_statement.add_statements_calls[0]).is_same(a)


func test_random_block_rng_in_middle_bucket() -> void:
	var a: Array[WeavlyModel.Statement] = _body("a")
	var b: Array[WeavlyModel.Statement] = _body("b")
	var c: Array[WeavlyModel.Statement] = _body("c")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), a),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(30.0), b),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(60.0), c),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	_roll_between(0.1, 0.4)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(1)
	assert_that(_statement.add_statements_calls[0]).is_same(b)


func test_random_block_rng_in_last_bucket() -> void:
	var a: Array[WeavlyModel.Statement] = _body("a")
	var b: Array[WeavlyModel.Statement] = _body("b")
	var c: Array[WeavlyModel.Statement] = _body("c")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), a),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(30.0), b),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(60.0), c),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	_roll_between(0.4, 1.0)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(1)
	assert_that(_statement.add_statements_calls[0]).is_same(c)


func test_random_block_filters_out_false_conditions() -> void:
	var skipped: Array[WeavlyModel.Statement] = _body("skipped")
	var picked: Array[WeavlyModel.Statement] = _body("picked")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(false), _weight(10.0), skipped),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), picked),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(1)
	assert_that(_statement.add_statements_calls[0]).is_same(picked)


func test_random_block_excludes_zero_weight_cases() -> void:
	var zero: Array[WeavlyModel.Statement] = _body("zero")
	var picked: Array[WeavlyModel.Statement] = _body("picked")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(0.0), zero),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), picked),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(1)
	assert_that(_statement.add_statements_calls[0]).is_same(picked)


func test_random_block_no_eligible_cases_does_nothing() -> void:
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(false), _weight(10.0), _body("a")),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(0.0), _body("b")),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_that(_statement.add_statements_calls.size()).is_equal(0)


# =====================
# Errors leave state unchanged
# =====================


func _add_score() -> void:
	declare(_engine, WeavlyModel.NumberVariable.new("score", 10.0, 0.0, 100.0))


func _run_set(id: String, expression: WeavlyModel.WeavlyExpression) -> void:
	WeavlyStatementExecutor.execute_set_statement(
		WeavlyModel.SetStatement.new(id, expression), _engine
	)


func test_set_with_an_undefined_variable_in_the_expression_keeps_the_value() -> void:
	_add_score()
	var expression: WeavlyModel.BinaryExpression = WeavlyModel.BinaryExpression.new(
		"+", WeavlyModel.Identifier.new("scroe"), WeavlyModel.Number.new(5.0)
	)
	_run_set("score", expression)
	assert_logged(["Variable 'scroe' isn't defined."])
	assert_that(_engine.get_variable("score")).is_equal(10.0)


func test_set_with_a_value_of_the_wrong_type_keeps_the_value() -> void:
	_add_score()
	_run_set("score", WeavlyModel.StringLiteral.new("high"))
	assert_logged(
		["Can't set variable 'score' to a value of type 'String' because it's a number."]
	)
	assert_that(_engine.get_variable("score")).is_equal(10.0)


func test_set_of_an_undefined_variable_creates_nothing() -> void:
	_add_score()
	_run_set("scroe", WeavlyModel.Number.new(5.0))
	assert_logged(["Can't set variable 'scroe' because it isn't declared."])
	assert_bool(_engine.variable_service.has("scroe")).is_false()
	assert_that(_engine.get_variable("score")).is_equal(10.0)


func test_random_weight_that_fails_counts_as_zero() -> void:
	var picked: Array[WeavlyModel.Statement] = _body("picked")
	var missing: WeavlyModel.Identifier = WeavlyModel.Identifier.new("missing")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), missing, _body()),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(1.0), picked),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_logged(["Variable 'missing' isn't defined."])
	assert_that(_statement.add_statements_calls[0]).is_same(picked)


func test_random_weight_of_a_case_whose_condition_is_false_is_not_evaluated() -> void:
	var picked: Array[WeavlyModel.Statement] = _body("picked")
	var missing: WeavlyModel.Identifier = WeavlyModel.Identifier.new("missing")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(false), missing, _body()),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(1.0), picked),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_that(_statement.add_statements_calls[0]).is_same(picked)


func test_random_weight_that_is_not_a_number_counts_as_zero() -> void:
	var picked: Array[WeavlyModel.Statement] = _body("picked")
	var text: WeavlyModel.StringLiteral = WeavlyModel.StringLiteral.new("x")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), text, _body()),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(1.0), picked),
	]
	var block: WeavlyModel.RandomBlock = WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine)
	assert_logged(["Random weight can't be of type 'String', using 0 instead."])
	assert_that(_statement.add_statements_calls[0]).is_same(picked)


func test_case_condition_that_fails_counts_as_false() -> void:
	var picked: Array[WeavlyModel.Statement] = _body("picked")
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(WeavlyModel.Identifier.new("missing"), _body("skipped")),
		WeavlyModel.WhenCase.new(_bool_expr(true), picked),
	]
	var block: WeavlyModel.MatchBlock = WeavlyModel.MatchBlock.new(
		WeavlyModel.MatchModifier.FIRST, cases
	)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_logged(["Variable 'missing' isn't defined."])
	assert_that(_statement.add_statements_calls[0]).is_same(picked)


# =====================
# Visits
# =====================


# "here" detoured from "below".
func _run_in_a_detour(statement: WeavlyModel.Statement) -> void:
	var body: Array[WeavlyModel.Statement] = []
	for id: String in ["below", "here"]:
		_engine.story.add_node(WeavlyModel.WeavlyNode.new(id, body))
	_engine._location_stack.assign(["below", "here"])
	WeavlyStatementExecutor.execute_statement(statement, _engine)


func test_jump_records_a_visit_to_every_running_node() -> void:
	_run_in_a_detour(WeavlyModel.JumpStatement.new("there"))
	assert_int(_engine.count_service.get_visit_count("here")).is_equal(1)
	assert_int(_engine.count_service.get_visit_count("below")).is_equal(1)
	assert_that(_engine.get_location_stack()).is_empty()


func test_set_defines_an_undefined_extern() -> void:
	var variable: WeavlyModel.NumberVariable = WeavlyModel.NumberVariable.new(
		"reputation", 0.0, null, null
	)
	variable.extern = true
	declare(_engine, variable)
	_run_set("reputation", WeavlyModel.Number.new(2.0))
	assert_that(_engine.get_variable("reputation")).is_equal(2.0)
