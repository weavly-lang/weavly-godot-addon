class_name WeavlyTextUtils

const VARIABLE_PATTERN = r"\{\$([A-Za-z_][A-Za-z0-9_]*)\}"

static var _cached_variable_regex: RegEx = null

static var default_variable_pipeline: Array[Callable] = [
	func(value): return WeavlyTextUtils.format_float_trim_zero(value)
]


static func inject_variables(
	text: String, engine: WeavlyEngine, pipeline: Array[Callable] = default_variable_pipeline
) -> String:
	var regex = _get_variable_regex()
	var out = ""
	var last_end = 0
	var reported: Array[String] = []

	for m in regex.search_all(text):
		var start = m.get_start()
		var end = m.get_end()
		out += text.substr(last_end, start - last_end)
		last_end = end

		var variable_name = m.get_string(1)
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


static func fill_narration_line(
	narration_line: WeavlyModel.NarrationLine, engine: WeavlyEngine
) -> WeavlyModel.NarrationLine:
	var filled: WeavlyModel.NarrationLine = WeavlyModel.NarrationLine.new(
		inject_variables(narration_line.text, engine)
	)
	filled.raw_text = narration_line.text
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
		name, character_line.name_is_id, inject_variables(character_line.text, engine)
	)
	filled.raw_name = character_line.name
	filled.raw_text = character_line.text
	filled.line = character_line.line
	return filled


static func fill_option(option: WeavlyModel.Option, engine: WeavlyEngine) -> WeavlyModel.Option:
	var filled: WeavlyModel.Option = WeavlyModel.Option.new(
		option.condition, inject_variables(option.text, engine), option.body, option.hint
	)
	filled.raw_text = option.text
	filled.line = option.line
	return filled


static func format_string_strip_quotes(value: Variant) -> Variant:
	if (
		is_instance_of(value, Variant.Type.TYPE_STRING)
		and value.length() >= 2
		and value.begins_with('"')
		and value.ends_with('"')
	):
		return value.substr(1, value.length() - 2)

	return value


# Rounds to at most two decimals and drops them for whole numbers.
static func format_float_trim_zero(value: Variant) -> Variant:
	if value is not float:
		return value
	var rounded: float = snappedf(value, 0.01)
	if WeavlyExpressionEvaluator.approximately_equal(rounded, round(rounded)):
		return int(round(rounded))
	return rounded


static func _get_variable_regex() -> RegEx:
	if _cached_variable_regex == null:
		_cached_variable_regex = RegEx.new()
		_cached_variable_regex.compile(VARIABLE_PATTERN)
	return _cached_variable_regex
