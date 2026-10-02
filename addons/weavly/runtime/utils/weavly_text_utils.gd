class_name WeavlyTextUtils

static var default_variable_pipeline: Array[Callable] = [format_float_trim_zero]


# A failing expression is reported by the evaluator and left out of the text.
static func fill_text(
	segments: Array, engine: WeavlyEngine, pipeline: Array[Callable] = default_variable_pipeline
) -> String:
	var out: String = ""
	for segment: Variant in segments:
		if segment is String:
			out += segment
			continue
		var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(segment, engine)
		if WeavlyExpressionEvaluator.is_error(value):
			continue
		for method: Callable in pipeline:
			value = method.call(value)
		out += str(value)
	return out


static func fill_narration_line(
	narration_line: WeavlyModel.NarrationLine, engine: WeavlyEngine
) -> WeavlyModel.NarrationLine:
	var filled: WeavlyModel.NarrationLine = WeavlyModel.NarrationLine.new(narration_line.segments)
	filled.text = fill_text(narration_line.segments, engine)
	filled.line = narration_line.line
	return filled


# A name that is an id names a string variable holding the speaker's name.
static func fill_character_line(
	character_line: WeavlyModel.CharacterLine, engine: WeavlyEngine
) -> WeavlyModel.CharacterLine:
	var name: String = character_line.name
	if character_line.name_is_id:
		if engine.variable_service.has(name):
			name = str(engine.variable_service.get_variable(name))
		else:
			WeavlyExpressionEvaluator.report_undefined_variable(name, engine)
	var filled: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new(
		name, character_line.name_is_id, character_line.segments
	)
	filled.raw_name = character_line.name
	filled.text = fill_text(character_line.segments, engine)
	filled.line = character_line.line
	return filled


# Null when an argument fails; the evaluator has reported it.
static func fill_command(
	command: WeavlyModel.CommandStatement, engine: WeavlyEngine
) -> WeavlyModel.CommandStatement:
	var values: Array = []
	for arg: WeavlyModel.WeavlyExpression in command.args:
		var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(arg, engine)
		if WeavlyExpressionEvaluator.is_error(value):
			return null
		values.append(value)
	var filled: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new(
		command.id, command.args
	)
	filled.values = values
	filled.line = command.line
	return filled


# Rounds to at most two decimals and drops them for whole numbers.
static func format_float_trim_zero(value: Variant) -> Variant:
	if value is not float:
		return value
	var rounded: float = snappedf(value, 0.01)
	if WeavlyExpressionEvaluator.approximately_equal(rounded, round(rounded)):
		return int(round(rounded))
	return rounded
