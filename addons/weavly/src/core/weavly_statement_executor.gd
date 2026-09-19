class_name WeavlyStatementExecutor


static func execute_statement(statement: WeavlyModel.Statement, engine: WeavlyEngine) -> void:
	if is_instance_of(statement, WeavlyModel.NarrationLine):
		execute_narration_line(statement, engine)
	elif is_instance_of(statement, WeavlyModel.CharacterLine):
		execute_character_line(statement, engine)
	elif is_instance_of(statement, WeavlyModel.SetStatement):
		execute_set_statement(statement, engine)
	elif is_instance_of(statement, WeavlyModel.GotoStatement):
		execute_goto_statement(statement, engine)
	elif is_instance_of(statement, WeavlyModel.FinishStatement):
		execute_finish_statement(statement, engine)
	elif is_instance_of(statement, WeavlyModel.CommandStatement):
		execute_command_statement(statement, engine)
	elif is_instance_of(statement, WeavlyModel.MatchBlock):
		execute_match_block(statement, engine)
	elif is_instance_of(statement, WeavlyModel.OptionBlock):
		execute_option_block(statement, engine)
	elif is_instance_of(statement, WeavlyModel.RandomBlock):
		execute_random_block(statement, engine, randf)
	else:
		push_error("Can't execute statement, got unknown type '%s'" % [str(typeof(statement))])


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
	var value = WeavlyExpressionEvaluator.evaluate_expression(set_statement.expression, engine)
	engine.variable_service.set_variable(set_statement.id, value)


static func execute_goto_statement(
	goto_statement: WeavlyModel.GotoStatement, engine: WeavlyEngine
) -> void:
	engine.enter_node(goto_statement.id)


static func execute_finish_statement(
	_finish_statement: WeavlyModel.FinishStatement, engine: WeavlyEngine
) -> void:
	engine.finish()


static func execute_command_statement(
	command_statement: WeavlyModel.CommandStatement, engine: WeavlyEngine
) -> void:
	engine.command_service.execute_command(command_statement)


static func execute_match_block(match_block: WeavlyModel.MatchBlock, engine: WeavlyEngine) -> void:
	var cases: Array[WeavlyModel.WhenCase] = match_block.cases
	match match_block.modifier:
		WeavlyModel.MatchModifier.FIRST:
			_execute_first_case(cases, engine)
		WeavlyModel.MatchModifier.LAST:
			_execute_last_case(cases, engine)
		WeavlyModel.MatchModifier.ALL:
			_execute_all_cases(cases, engine)


static func _execute_first_case(cases: Array[WeavlyModel.WhenCase], engine: WeavlyEngine) -> void:
	for case: WeavlyModel.WhenCase in cases:
		var condition = WeavlyExpressionEvaluator.evaluate_condition(case.condition, engine)
		if condition:
			engine.statement_service.add_statements(case.body)
			return


static func _execute_last_case(cases: Array[WeavlyModel.WhenCase], engine: WeavlyEngine) -> void:
	for i in range(cases.size() - 1, -1, -1):
		var case: WeavlyModel.WhenCase = cases[i]
		var condition = WeavlyExpressionEvaluator.evaluate_condition(case.condition, engine)
		if condition:
			engine.statement_service.add_statements(case.body)
			return


static func _execute_all_cases(cases: Array[WeavlyModel.WhenCase], engine: WeavlyEngine) -> void:
	var valid_case_bodies: Array[Array] = []
	for case: WeavlyModel.WhenCase in cases:
		var condition = WeavlyExpressionEvaluator.evaluate_condition(case.condition, engine)
		if condition:
			valid_case_bodies.append(case.body)
	engine.statement_service.add_statement_groups(valid_case_bodies)


static func execute_option_block(
	option_block: WeavlyModel.OptionBlock, engine: WeavlyEngine
) -> void:
	var possible_options: Array[WeavlyModel.Option] = []
	for option: WeavlyModel.Option in option_block.options:
		var condition: bool = WeavlyExpressionEvaluator.evaluate_condition(
			option.condition, engine
		)
		if condition:
			possible_options.append(option)

	if possible_options.is_empty():
		return

	engine.option_service.add_options(possible_options)


static func execute_random_block(
	random_block: WeavlyModel.RandomBlock,
	engine: WeavlyEngine,
	rng: Callable = randf,
) -> void:
	var possible_cases: Array[WeavlyModel.RandomCase] = []
	var evaluated_weights: Array[float] = []
	var total_weight: float = 0
	for case: WeavlyModel.RandomCase in random_block.cases:
		var condition: bool = WeavlyExpressionEvaluator.evaluate_condition(case.condition, engine)
		var weight: float = WeavlyExpressionEvaluator.evaluate_expression(case.weight, engine)
		if condition and weight > 0:
			possible_cases.append(case)
			evaluated_weights.append(weight)
			total_weight += weight

	if possible_cases.is_empty() or total_weight <= 0:
		return

	var random: float = rng.call() * total_weight
	var current: float = 0.0
	for i in possible_cases.size():
		current += evaluated_weights[i]
		if random <= current:
			engine.statement_service.add_statements(possible_cases[i].body)
			return
