class_name WeavlyStatementExecutor

const UNDEFINED_SET_TARGET = "Can't set variable '%s' because it isn't defined."
const WRONG_WEIGHT_TYPE = "Random weight can't be of type '%s', using 0 instead."


static func execute_statement(statement: WeavlyModel.Statement, engine: WeavlyEngine) -> void:
	engine.current_line = statement.line
	if statement is WeavlyModel.NarrationLine:
		execute_narration_line(statement, engine)
	elif statement is WeavlyModel.CharacterLine:
		execute_character_line(statement, engine)
	elif statement is WeavlyModel.SetStatement:
		execute_set_statement(statement, engine)
	elif statement is WeavlyModel.GotoStatement:
		execute_goto_statement(statement, engine)
	elif statement is WeavlyModel.FinishStatement:
		execute_finish_statement(statement, engine)
	elif statement is WeavlyModel.CommandStatement:
		execute_command_statement(statement, engine)
	elif statement is WeavlyModel.MatchBlock:
		execute_match_block(statement, engine)
	elif statement is WeavlyModel.OptionBlock:
		execute_option_block(statement, engine)
	elif statement is WeavlyModel.RandomBlock:
		execute_random_block(statement, engine, engine.rng.randf)
	elif statement is WeavlyModel.DrawStatement:
		execute_draw_statement(statement, engine)
	else:
		engine.report_error(
			"Can't execute statement of type '%s'." % type_string(typeof(statement))
		)


static func execute_narration_line(
	narration_line: WeavlyModel.NarrationLine, engine: WeavlyEngine
) -> void:
	engine.line_service.execute_narration_line(narration_line)


static func execute_character_line(
	character_line: WeavlyModel.CharacterLine, engine: WeavlyEngine
) -> void:
	engine.line_service.execute_character_line(character_line)


static func execute_set_statement(
	set_statement: WeavlyModel.SetStatement, engine: WeavlyEngine
) -> void:
	var declared: WeavlyModel.Variable = engine.variable_service.get_declaration(set_statement.id)
	if declared == null:
		engine.report_error(UNDEFINED_SET_TARGET % set_statement.id)
		return
	var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(
		set_statement.expression, engine
	)
	if WeavlyExpressionEvaluator.is_error(value):
		return
	if typeof(value) != typeof(declared.value):
		engine.report_error(
			(
				WeavlyVariableService.WRONG_TYPE
				% [set_statement.id, type_string(typeof(value)), declared.get_type_name()]
			)
		)
		return
	engine.variable_service.set_variable(set_statement.id, value)


static func execute_goto_statement(
	goto_statement: WeavlyModel.GotoStatement, engine: WeavlyEngine
) -> void:
	engine.leave_current_node()
	engine.enter_node(goto_statement.id)


# Without an eligible node, execution continues with the next statement.
static func execute_draw_statement(
	draw_statement: WeavlyModel.DrawStatement, engine: WeavlyEngine
) -> void:
	var node_id: String = WeavlyStoryletSelector.draw(engine, draw_statement.pools)
	if node_id == "":
		return
	engine.leave_current_node()
	engine.enter_node(node_id)


static func execute_finish_statement(
	_finish_statement: WeavlyModel.FinishStatement, engine: WeavlyEngine
) -> void:
	engine.leave_current_node()
	engine.finish()


static func execute_command_statement(
	command_statement: WeavlyModel.CommandStatement, engine: WeavlyEngine
) -> void:
	var args: Array = []
	for arg: WeavlyModel.WeavlyExpression in command_statement.args:
		var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(arg, engine)
		if WeavlyExpressionEvaluator.is_error(value):
			return
		args.append(value)
	engine.command_service.execute_command(command_statement, args)


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
			engine.statement_service.add_statements(case.body)
			return


static func _execute_all_cases(cases: Array[WeavlyModel.WhenCase], engine: WeavlyEngine) -> void:
	var valid_case_bodies: Array[Array] = []
	for case: WeavlyModel.WhenCase in cases:
		if _condition_holds(case.line, case.condition, engine):
			valid_case_bodies.append(case.body)
	engine.statement_service.add_statement_groups(valid_case_bodies)


# Errors in the condition are reported at the case's line.
static func _condition_holds(
	line: int, condition: WeavlyModel.WeavlyExpression, engine: WeavlyEngine
) -> bool:
	engine.current_line = line
	return WeavlyExpressionEvaluator.evaluate_condition(condition, engine)


static func execute_option_block(
	option_block: WeavlyModel.OptionBlock, engine: WeavlyEngine
) -> void:
	var possible_options: Array[WeavlyModel.Option] = []
	for option: WeavlyModel.Option in option_block.options:
		if _condition_holds(option.line, option.condition, engine):
			possible_options.append(option)

	if possible_options.is_empty():
		return

	engine.option_service.add_options(possible_options)


static func execute_random_block(
	random_block: WeavlyModel.RandomBlock,
	engine: WeavlyEngine,
	rng: Callable,
) -> void:
	var possible_cases: Array[WeavlyModel.RandomCase] = []
	var evaluated_weights: Array[float] = []
	var total_weight: float = 0
	for case: WeavlyModel.RandomCase in random_block.cases:
		var condition: bool = _condition_holds(case.line, case.condition, engine)
		var weight: float = _evaluate_weight(case.weight, engine)
		if condition and weight > 0:
			possible_cases.append(case)
			evaluated_weights.append(weight)
			total_weight += weight

	if possible_cases.is_empty() or total_weight <= 0:
		return

	var random: float = rng.call() * total_weight
	var current: float = 0.0
	for i: int in possible_cases.size():
		current += evaluated_weights[i]
		if random <= current:
			engine.statement_service.add_statements(possible_cases[i].body)
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
