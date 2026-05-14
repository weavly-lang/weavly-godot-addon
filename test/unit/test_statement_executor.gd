extends GutTest

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

	func execute_command(command: WeavlyModel.CommandStatement) -> void:
		command_calls.append(command)


class _SpyOptionService:
	extends WeavlyOptionService
	var add_options_calls: Array[Array] = []

	func has_options() -> bool:
		return false

	func add_options(options: Array[WeavlyModel.Option]) -> void:
		add_options_calls.append(options)

	func choose_option(_option: WeavlyModel.Option) -> void:
		pass


class _SpyStatementService:
	extends WeavlyStatementService
	var add_statements_calls: Array[Array] = []
	var add_statement_groups_calls: Array[Array] = []

	func add_statements(statements: Array[WeavlyModel.Statement]) -> void:
		add_statements_calls.append(statements)

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


func before_each() -> void:
	_engine = add_child_autofree(FakeEngine.new())
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
	body.append(WeavlyModel.NarrationLine.new(tag))
	return body


func _bool_expr(v: bool) -> WeavlyModel.WeavlyExpression:
	if v:
		return WeavlyModel.TrueExpression.new()
	return WeavlyModel.FalseExpression.new()


# =====================
# Delegation: narration / character
# =====================


func test_narration_line_delegates_to_line_service() -> void:
	var line := WeavlyModel.NarrationLine.new("hello")
	WeavlyStatementExecutor.execute_statment(line, _engine)
	assert_eq(_line.narration_calls.size(), 1)
	assert_same(_line.narration_calls[0], line)


func test_character_line_delegates_to_line_service() -> void:
	var line := WeavlyModel.CharacterLine.new("Alice", false, "hi")
	WeavlyStatementExecutor.execute_statment(line, _engine)
	assert_eq(_line.character_calls.size(), 1)
	assert_same(_line.character_calls[0], line)


# =====================
# Delegation: command
# =====================


func test_command_statement_delegates_to_command_service() -> void:
	var command := WeavlyModel.CommandStatement.new("cmd", "do it")
	WeavlyStatementExecutor.execute_statment(command, _engine)
	assert_eq(_command.command_calls.size(), 1)
	assert_same(_command.command_calls[0], command)


# =====================
# Delegation: goto
# =====================


func test_goto_statement_delegates_to_engine_enter_node() -> void:
	var goto := WeavlyModel.GotoStatement.new("target_node")
	WeavlyStatementExecutor.execute_statment(goto, _engine)
	assert_eq(_engine.last_entered_node, "target_node")


# =====================
# Delegation: finish
# =====================


func test_finish_statement_delegates_to_engine_finish() -> void:
	var finish := WeavlyModel.FinishStatement.new()
	WeavlyStatementExecutor.execute_statment(finish, _engine)
	assert_true(_engine.did_finish)


# =====================
# execute_match_block — FIRST
# =====================


func test_match_first_picks_first_matching_case() -> void:
	var first := _body("first")
	var second := _body("second")
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("skip")),
		WeavlyModel.WhenCase.new(_bool_expr(true), first),
		WeavlyModel.WhenCase.new(_bool_expr(true), second),
	]
	var block := WeavlyModel.MatchBlock.new(WeavlyModel.MatchModifier.FIRST, cases)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_eq(_statement.add_statements_calls.size(), 1)
	assert_same(_statement.add_statements_calls[0], first)


func test_match_first_no_match_does_nothing() -> void:
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("a")),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("b")),
	]
	var block := WeavlyModel.MatchBlock.new(WeavlyModel.MatchModifier.FIRST, cases)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_eq(_statement.add_statements_calls.size(), 0)


# =====================
# execute_match_block — LAST
# =====================


func test_match_last_picks_last_matching_case() -> void:
	var first := _body("first")
	var last := _body("last")
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(true), first),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("skip")),
		WeavlyModel.WhenCase.new(_bool_expr(true), last),
	]
	var block := WeavlyModel.MatchBlock.new(WeavlyModel.MatchModifier.LAST, cases)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_eq(_statement.add_statements_calls.size(), 1)
	assert_same(_statement.add_statements_calls[0], last)


# =====================
# execute_match_block — ALL
# =====================


func test_match_all_collects_matching_cases_as_groups() -> void:
	var a := _body("a")
	var b := _body("b")
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(true), a),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("skip")),
		WeavlyModel.WhenCase.new(_bool_expr(true), b),
	]
	var block := WeavlyModel.MatchBlock.new(WeavlyModel.MatchModifier.ALL, cases)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_eq(_statement.add_statement_groups_calls.size(), 1)
	var groups: Array = _statement.add_statement_groups_calls[0]
	assert_eq(groups.size(), 2)
	assert_same(groups[0], a)
	assert_same(groups[1], b)


func test_match_all_with_no_matches_passes_empty_groups() -> void:
	var cases: Array[WeavlyModel.WhenCase] = [
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("a")),
		WeavlyModel.WhenCase.new(_bool_expr(false), _body("b")),
	]
	var block := WeavlyModel.MatchBlock.new(WeavlyModel.MatchModifier.ALL, cases)
	WeavlyStatementExecutor.execute_match_block(block, _engine)
	assert_eq(_statement.add_statement_groups_calls.size(), 1)
	assert_eq((_statement.add_statement_groups_calls[0] as Array).size(), 0)


# =====================
# execute_option_block
# =====================


func test_option_block_filters_options_by_condition() -> void:
	var keep_a := WeavlyModel.Option.new(_bool_expr(true), "a", _body("a"), false)
	var drop := WeavlyModel.Option.new(_bool_expr(false), "b", _body("b"), false)
	var keep_c := WeavlyModel.Option.new(_bool_expr(true), "c", _body("c"), false)
	var options: Array[WeavlyModel.Option] = [keep_a, drop, keep_c]
	var block := WeavlyModel.OptionBlock.new(options)
	WeavlyStatementExecutor.execute_option_block(block, _engine)
	assert_eq(_option.add_options_calls.size(), 1)
	var passed: Array = _option.add_options_calls[0]
	assert_eq(passed.size(), 2)
	assert_same(passed[0], keep_a)
	assert_same(passed[1], keep_c)


func test_option_block_with_no_passing_options_passes_empty_array() -> void:
	var block := WeavlyModel.OptionBlock.new(
		[WeavlyModel.Option.new(_bool_expr(false), "a", _body("a"), false)]
	)
	WeavlyStatementExecutor.execute_option_block(block, _engine)
	assert_eq(_option.add_options_calls.size(), 1)
	assert_eq((_option.add_options_calls[0] as Array).size(), 0)


# =====================
# execute_random_block
# =====================


func _weight(v: float) -> WeavlyModel.Number:
	return WeavlyModel.Number.new(v)


func _const_rng(value: float) -> Callable:
	return func(): return value


func test_random_block_picks_case_based_on_rng() -> void:
	# Weights: a=10, b=30, c=60. Total=100.
	# rng=0.05 -> random=5 -> falls in a's bucket (0, 10].
	var a := _body("a")
	var b := _body("b")
	var c := _body("c")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), a),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(30.0), b),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(60.0), c),
	]
	var block := WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine, _const_rng(0.05))
	assert_eq(_statement.add_statements_calls.size(), 1)
	assert_same(_statement.add_statements_calls[0], a)


func test_random_block_rng_in_middle_bucket() -> void:
	# rng=0.15 -> random=15 -> falls in b's bucket (10, 40].
	var a := _body("a")
	var b := _body("b")
	var c := _body("c")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), a),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(30.0), b),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(60.0), c),
	]
	var block := WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine, _const_rng(0.15))
	assert_eq(_statement.add_statements_calls.size(), 1)
	assert_same(_statement.add_statements_calls[0], b)


func test_random_block_rng_in_last_bucket() -> void:
	# rng=0.85 -> random=85 -> falls in c's bucket (40, 100].
	var a := _body("a")
	var b := _body("b")
	var c := _body("c")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), a),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(30.0), b),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(60.0), c),
	]
	var block := WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine, _const_rng(0.85))
	assert_eq(_statement.add_statements_calls.size(), 1)
	assert_same(_statement.add_statements_calls[0], c)


func test_random_block_filters_out_false_conditions() -> void:
	# The false-conditioned case must never be selected, regardless of rng.
	var skipped := _body("skipped")
	var picked := _body("picked")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(false), _weight(10.0), skipped),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), picked),
	]
	var block := WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine, _const_rng(0.0))
	assert_eq(_statement.add_statements_calls.size(), 1)
	assert_same(_statement.add_statements_calls[0], picked)


func test_random_block_excludes_zero_weight_cases() -> void:
	var zero := _body("zero")
	var picked := _body("picked")
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(0.0), zero),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(10.0), picked),
	]
	var block := WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine, _const_rng(0.0))
	assert_eq(_statement.add_statements_calls.size(), 1)
	assert_same(_statement.add_statements_calls[0], picked)


func test_random_block_no_eligible_cases_does_nothing() -> void:
	var cases: Array[WeavlyModel.RandomCase] = [
		WeavlyModel.RandomCase.new(_bool_expr(false), _weight(10.0), _body("a")),
		WeavlyModel.RandomCase.new(_bool_expr(true), _weight(0.0), _body("b")),
	]
	var block := WeavlyModel.RandomBlock.new(cases)
	WeavlyStatementExecutor.execute_random_block(block, _engine, _const_rng(0.5))
	assert_eq(_statement.add_statements_calls.size(), 0)
