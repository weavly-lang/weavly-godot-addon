class_name WeavlyStatementExecutor


static func execute_statment(statement: WeavlyModel.Statement, engine: WeavlyEngine) -> void:
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
	elif is_instance_of(statement, WeavlyModel.IfBlock):
		execute_if_block(statement, engine)
	elif is_instance_of(statement, WeavlyModel.OptionBlock):
		execute_option_block(statement, engine)
	else:
		push_error("Cant execute statement, got unknown type '%s'" % [str(typeof(statement))])


static func execute_narration_line(narration_line: WeavlyModel.NarrationLine, engine: WeavlyEngine) -> void:
	engine.line_service.execute_narration_line(narration_line)


static func execute_character_line(character_line: WeavlyModel.CharacterLine, engine: WeavlyEngine) -> void:
	engine.line_service.execute_character_line(character_line)


static func execute_set_statement(set_statement: WeavlyModel.SetStatement, engine: WeavlyEngine) -> void:
	var value = WeavlyExpressionEvaluator.evaluate_expression(set_statement.expression, engine)
	engine.variable_service.set_variable(set_statement.id, value)


static func execute_goto_statement(goto_statement: WeavlyModel.GotoStatement, engine: WeavlyEngine) -> void:
	engine.enter_node(goto_statement.id)


static func execute_finish_statement(_finish_statement: WeavlyModel.FinishStatement, engine: WeavlyEngine) -> void:
	engine.finish()


static func execute_command_statement(command_statement: WeavlyModel.CommandStatement, engine: WeavlyEngine) -> void:
	engine.command_service.execute_command(command_statement)


static func execute_if_block(if_block: WeavlyModel.IfBlock, engine: WeavlyEngine) -> void:
	for case: WeavlyModel.IfCase in if_block.cases:
		var condition = WeavlyExpressionEvaluator.evaluate_condition(case.condition, engine)
		if condition:
			engine.statement_service.add_statements(case.body)
			return


static func execute_option_block(option_block: WeavlyModel.OptionBlock, engine: WeavlyEngine) -> void:
	var possible_options: Array[WeavlyModel.Option] = []
	for option: WeavlyModel.Option in option_block.options:
		var condition: bool = WeavlyExpressionEvaluator.evaluate_condition(option.condition, engine)
		if condition:
			possible_options.append(option)
	engine.option_service.add_options(possible_options)
