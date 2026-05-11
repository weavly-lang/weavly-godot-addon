class_name WeavlyTextUtils

const VARIABLE_PATTERN = r"\{\$([A-Za-z_][A-Za-z0-9_]*)\}"

static var _cached_variable_regex: RegEx = null

static var default_variable_pipeline: Array[Callable] = [
	func(value): return WeavlyTextUtils.format_string_strip_quotes(value),
	func(value): return WeavlyTextUtils.format_float_trim_zero(value)
]


static func inject_variables(
	text: String, engine: WeavlyEngine, pipeline: Array[Callable] = default_variable_pipeline
) -> String:
	var regex = _get_variable_regex()
	var out = ""
	var last_end = 0

	for m in regex.search_all(text):
		var start = m.get_start()
		var end = m.get_end()
		out += text.substr(last_end, start - last_end)

		var variable_name = m.get_string(1)
		var value: Variant = engine.variable_service.get_variable(variable_name)
		for method: Callable in pipeline:
			value = method.call(value)

		out += str(value)
		last_end = end

	out += text.substr(last_end)
	return out


static func format_string_strip_quotes(value: Variant) -> Variant:
	if (
		is_instance_of(value, Variant.Type.TYPE_STRING)
		and value.length() >= 2
		and value.begins_with('"')
		and value.ends_with('"')
	):
		return value.substr(1, value.length() - 2)
	else:
		return value


static func format_float_trim_zero(value: Variant) -> Variant:
	if is_instance_of(value, Variant.Type.TYPE_FLOAT) and is_equal_approx(value, round(value)):
		return int(round(value))
	else:
		return value


static func _get_variable_regex() -> RegEx:
	if _cached_variable_regex == null:
		_cached_variable_regex = RegEx.new()
		_cached_variable_regex.compile(VARIABLE_PATTERN)
	return _cached_variable_regex
