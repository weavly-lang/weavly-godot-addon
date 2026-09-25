class_name WeavlyTextUtils

const VARIABLE_PATTERN = r"\{\$([A-Za-z_][A-Za-z0-9_]*)\}"

static var default_variable_pipeline: Array[Callable] = [format_float_trim_zero]

static var _variable_regex: RegEx = RegEx.create_from_string(VARIABLE_PATTERN)


static func inject_variables(
	text: String, engine: WeavlyEngine, pipeline: Array[Callable] = default_variable_pipeline
) -> String:
	var out: String = ""
	var last_end: int = 0
	var reported: Array[String] = []

	for m: RegExMatch in _variable_regex.search_all(text):
		var start: int = m.get_start()
		var end: int = m.get_end()
		out += text.substr(last_end, start - last_end)
		last_end = end

		var variable_name: String = m.get_string(1)
		if not engine.variable_service.has(variable_name):
			if variable_name not in reported:
				WeavlyExpressionEvaluator.report_undefined_variable(variable_name, engine)
				reported.append(variable_name)
			out += m.get_string()
			continue

		var value: Variant = engine.variable_service.get_variable(variable_name)
		for method: Callable in pipeline:
			value = method.call(value)
		out += str(value)

	out += text.substr(last_end)
	return out


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


static func fill_option(option: WeavlyModel.Option, engine: WeavlyEngine) -> WeavlyModel.Option:
	var filled: WeavlyModel.Option = WeavlyModel.Option.new(
		option.condition, option.segments, option.body, option.hint
	)
	filled.text = fill_text(option.segments, engine)
	filled.line = option.line
	return filled


static func fill_options(
	options: Array[WeavlyModel.Option], engine: WeavlyEngine
) -> Array[WeavlyModel.Option]:
	var filled: Array[WeavlyModel.Option] = []
	for option: WeavlyModel.Option in options:
		engine.current_line = option.line
		filled.append(fill_option(option, engine))
	return filled


static func fill_option_block(
	block: WeavlyModel.OptionBlock, engine: WeavlyEngine
) -> WeavlyModel.OptionBlock:
	var filled: WeavlyModel.OptionBlock = WeavlyModel.OptionBlock.new(
		fill_options(block.options, engine)
	)
	filled.line = block.line
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
