class_name WeavlyStatementExecutor

const UNKNOWN_STATEMENT = "Can't execute an unknown statement."
const WRONG_WEIGHT_TYPE = "Random weight can't be of type '%s', using 0 instead."


static func execute_statement(statement: WeavlyModel.Statement, engine: WeavlyEngine) -> void:
	engine.current_line = statement.line
	engine.statement_reached.emit(statement)
	if statement is WeavlyModel.NarrationLine:
		execute_narration_line(statement, engine)
	elif statement is WeavlyModel.CharacterLine:
		execute_character_line(statement, engine)
	elif statement is WeavlyModel.SetStatement:
		execute_set_statement(statement, engine)
	elif statement is WeavlyModel.JumpStatement:
		execute_jump_statement(statement, engine)
	elif statement is WeavlyModel.DetourStatement:
		execute_detour_statement(statement, engine)
	elif statement is WeavlyModel.FinishStatement:
		execute_finish_statement(statement, engine)
	elif statement is WeavlyModel.DoStatement:
		execute_do_statement(statement, engine)
	elif statement is WeavlyModel.MatchBlock:
		execute_match_block(statement, engine)
	elif statement is WeavlyModel.OptionBlock:
		execute_option_block(statement, engine)
	elif statement is WeavlyModel.RandomBlock:
		execute_random_block(statement, engine)
	elif statement is WeavlyModel.DrawStatement:
		execute_draw_statement(statement, engine)
	else:
		engine.report_error(UNKNOWN_STATEMENT)


static func execute_narration_line(
	narration_line: WeavlyModel.NarrationLine, engine: WeavlyEngine
) -> void:
	_pass_line(WeavlyTextUtils.fill_narration_line(narration_line, engine), engine)


static func execute_character_line(
	character_line: WeavlyModel.CharacterLine, engine: WeavlyEngine
) -> void:
	_pass_line(WeavlyTextUtils.fill_character_line(character_line, engine), engine)


static func _pass_line(filled: WeavlyModel.LineStatement, engine: WeavlyEngine) -> void:
	if engine.is_rendering():
		engine.add_rendered(filled)
	else:
		engine.reach_line(filled)


static func execute_set_statement(
	set_statement: WeavlyModel.SetStatement, engine: WeavlyEngine
) -> void:
	var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(
		set_statement.expression, engine
	)
	if not WeavlyExpressionEvaluator.is_error(value):
		engine.set_variable(set_statement.id, value)


static func execute_jump_statement(
	jump_statement: WeavlyModel.JumpStatement, engine: WeavlyEngine
) -> void:
	engine.leave_all_nodes()
	engine.enter_node(jump_statement.id)


static func execute_detour_statement(
	detour_statement: WeavlyModel.DetourStatement, engine: WeavlyEngine
) -> void:
	engine.detour(detour_statement.id)


# The drawn node runs like a detour; without an eligible node, execution continues right away.
static func execute_draw_statement(
	draw_statement: WeavlyModel.DrawStatement, engine: WeavlyEngine
) -> void:
	var node_id: String = WeavlyStoryletSelector.draw(engine, draw_statement.pools)
	if node_id == "":
		return
	engine.detour(node_id)


static func execute_finish_statement(
	_finish_statement: WeavlyModel.FinishStatement, engine: WeavlyEngine
) -> void:
	engine.finish()


static func execute_do_statement(
	do_statement: WeavlyModel.DoStatement, engine: WeavlyEngine
) -> void:
	var filled: WeavlyModel.DoStatement = WeavlyTextUtils.fill_do(do_statement, engine)
	if filled == null:
		return
	if engine.is_rendering():
		engine.add_rendered(filled)
	else:
		engine.run_do(filled)


static func execute_match_block(match_block: WeavlyModel.MatchBlock, engine: WeavlyEngine) -> void:
	var cases: Array[WeavlyModel.WhenCase] = match_block.cases
	match match_block.modifier:
		WeavlyModel.MatchModifier.FIRST:
			_execute_first_case(cases, engine)
		WeavlyModel.MatchModifier.LAST:
			var reversed: Array[WeavlyModel.WhenCase] = cases.duplicate()
			reversed.reverse()
			_execute_first_case(reversed, engine)
		WeavlyModel.MatchModifier.ALL:
			_execute_all_cases(cases, engine)


static func _execute_first_case(cases: Array[WeavlyModel.WhenCase], engine: WeavlyEngine) -> void:
	for case: WeavlyModel.WhenCase in cases:
		if _condition_holds(case.line, case.condition, engine):
			engine.add_statements(case.body)
			return


static func _execute_all_cases(cases: Array[WeavlyModel.WhenCase], engine: WeavlyEngine) -> void:
	var valid_case_bodies: Array[Array] = []
	for case: WeavlyModel.WhenCase in cases:
		if _condition_holds(case.line, case.condition, engine):
			valid_case_bodies.append(case.body)
	engine.add_statement_groups(valid_case_bodies)


# Errors in the condition are reported at the case's line.
static func _condition_holds(
	line: int, condition: WeavlyModel.WeavlyExpression, engine: WeavlyEngine
) -> bool:
	engine.current_line = line
	return WeavlyExpressionEvaluator.evaluate_condition(condition, engine)


static func execute_option_block(
	option_block: WeavlyModel.OptionBlock, engine: WeavlyEngine
) -> void:
	var options: Array[WeavlyModel.Option] = WeavlyOptionBuilder.offer(option_block, engine)
	if options.is_empty():
		return
	if engine.is_rendering():
		var rendered: WeavlyModel.OptionBlock = WeavlyModel.OptionBlock.new(option_block.items)
		rendered.line = option_block.line
		rendered.options = options
		engine.add_rendered(rendered)
	else:
		engine.offer_options(options)


static func execute_random_block(
	random_block: WeavlyModel.RandomBlock, engine: WeavlyEngine
) -> void:
	var possible_cases: Array[WeavlyModel.RandomCase] = []
	var evaluated_weights: Array[float] = []
	var total_weight: float = 0
	for case: WeavlyModel.RandomCase in random_block.cases:
		if not _condition_holds(case.line, case.condition, engine):
			continue
		var weight: float = _evaluate_weight(case.weight, engine)
		if weight > 0:
			possible_cases.append(case)
			evaluated_weights.append(weight)
			total_weight += weight

	if possible_cases.is_empty() or total_weight <= 0:
		return

	var random: float = engine.rng.randf() * total_weight
	var current: float = 0.0
	for i: int in possible_cases.size():
		current += evaluated_weights[i]
		if random <= current:
			engine.add_statements(possible_cases[i].body)
			return


static func _evaluate_weight(
	expression: WeavlyModel.WeavlyExpression, engine: WeavlyEngine
) -> float:
	var weight: Variant = WeavlyExpressionEvaluator.evaluate_expression(expression, engine)
	if WeavlyExpressionEvaluator.is_error(weight):
		return 0.0
	if weight is not float:
		engine.report_error(WRONG_WEIGHT_TYPE % type_string(typeof(weight)))
		return 0.0
	return weight
