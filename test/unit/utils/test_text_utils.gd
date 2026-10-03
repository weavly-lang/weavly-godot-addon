# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")


func _make_engine() -> WeavlyEngine:
	var engine: WeavlyEngine = auto_free(FakeEngine.new())
	add_child(engine)
	return engine


# =====================
# format_float_trim_zero
# =====================


func test_trim_zero_whole_float_returns_int() -> void:
	assert_that(WeavlyTextUtils.format_float_trim_zero(5.0)).is_equal(5)


func test_trim_zero_fractional_float_unchanged() -> void:
	assert_that(WeavlyTextUtils.format_float_trim_zero(5.5)).is_equal(5.5)


func test_trim_zero_rounds_to_two_decimals() -> void:
	assert_float(WeavlyTextUtils.format_float_trim_zero(1.0 / 3.0)).is_equal_approx(0.33, 0.0001)
	assert_float(WeavlyTextUtils.format_float_trim_zero(2.678)).is_equal_approx(2.68, 0.0001)


func test_trim_zero_a_float_that_rounds_to_a_whole_number_returns_int() -> void:
	assert_that(WeavlyTextUtils.format_float_trim_zero(2.999)).is_equal(3)
	assert_that(WeavlyTextUtils.format_float_trim_zero(-0.001)).is_equal(0)


func test_trim_zero_keeps_the_decimals_of_a_large_number() -> void:
	var engine: WeavlyEngine = _make_engine()
	declare_variable(engine, "gold", 1000000.5)
	var text: String = WeavlyTextUtils.fill_text(_segments([{"variable": "gold"}]), engine)
	assert_that(text).is_equal("1000000.5")


func test_trim_zero_non_float_unchanged() -> void:
	assert_that(WeavlyTextUtils.format_float_trim_zero("hi")).is_equal("hi")


# =====================
# fill_text: formatting values
# =====================


func test_fill_text_keeps_quotes_that_are_part_of_the_value() -> void:
	var engine: WeavlyEngine = _make_engine()
	declare_variable(engine, "greeting", '"hello"')
	var text: String = WeavlyTextUtils.fill_text(_segments([{"variable": "greeting"}]), engine)
	assert_that(text).is_equal('"hello"')


func test_fill_text_trims_and_rounds_numbers() -> void:
	var engine: WeavlyEngine = _make_engine()
	declare_variable(engine, "score", 10.0)
	declare_variable(engine, "third", 1.0 / 3.0)
	declare_variable(engine, "sum", 0.1 + 0.2)
	declare_variable(engine, "half", 2.5)
	var segments: Array = _segments(
		[
			{"variable": "score"},
			" ",
			{"variable": "third"},
			" ",
			{"variable": "sum"},
			" ",
			{"variable": "half"},
		]
	)
	assert_that(WeavlyTextUtils.fill_text(segments, engine)).is_equal("10 0.33 0.3 2.5")


# =====================
# fill_*
# =====================


func _engine_with_name() -> WeavlyEngine:
	var engine: WeavlyEngine = _make_engine()
	declare_variable(engine, "name", "Ada")
	return engine


func _segments(text: Array) -> Array:
	return WeavlyDeserializer.compile_text({"text": text}, "test")


func test_fill_narration_line_copies_with_filled_text() -> void:
	var line: WeavlyModel.NarrationLine = WeavlyModel.NarrationLine.new(
		_segments(["Hi ", {"variable": "name"}])
	)
	line.line = 4
	var filled: WeavlyModel.NarrationLine = WeavlyTextUtils.fill_narration_line(
		line, _engine_with_name()
	)
	assert_that(filled.text).is_equal("Hi Ada")
	assert_that(filled.segments).is_same(line.segments)
	assert_int(filled.line).is_equal(4)
	assert_that(line.text).is_equal("")


func test_fill_character_line_resolves_a_name_that_is_an_id() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new(
		"name", true, _segments([{"variable": "name"}, "!"])
	)
	line.line = 5
	var filled: WeavlyModel.CharacterLine = WeavlyTextUtils.fill_character_line(
		line, _engine_with_name()
	)
	assert_that(filled.name).is_equal("Ada")
	assert_that(filled.text).is_equal("Ada!")
	assert_int(filled.line).is_equal(5)


func test_fill_character_line_keeps_a_literal_name() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("name", false, ["Hi"])
	var filled: WeavlyModel.CharacterLine = WeavlyTextUtils.fill_character_line(
		line, _engine_with_name()
	)
	assert_that(filled.name).is_equal("name")


func test_fill_character_line_with_an_undefined_name_variable_reports_it() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("speaker", true, ["Hi"])
	var filled: WeavlyModel.CharacterLine = WeavlyTextUtils.fill_character_line(
		line, _make_engine()
	)
	assert_that(filled.name).is_equal("speaker")
	assert_logged(["Variable 'speaker' isn't defined."])


func test_fill_command_copies_with_evaluated_values() -> void:
	var args: Array[WeavlyModel.WeavlyExpression] = [
		WeavlyModel.StringLiteral.new("door"), WeavlyModel.Identifier.new("name")
	]
	var command: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new("sound", args)
	command.line = 3
	var filled: WeavlyModel.CommandStatement = WeavlyTextUtils.fill_command(
		command, _engine_with_name()
	)
	assert_that(filled.values).is_equal(["door", "Ada"])
	assert_that(filled.args).is_same(command.args)
	assert_int(filled.line).is_equal(3)
	assert_that(command.values).is_empty()


func test_fill_command_with_a_failing_argument_is_null() -> void:
	var args: Array[WeavlyModel.WeavlyExpression] = [WeavlyModel.Identifier.new("missing")]
	var command: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new("sound", args)
	assert_object(WeavlyTextUtils.fill_command(command, _make_engine())).is_null()
	assert_logged(["Variable 'missing' isn't defined."])


# =====================
# fill_text
# =====================


func test_fill_text_joins_plain_text() -> void:
	assert_that(WeavlyTextUtils.fill_text(["Hello."], _make_engine())).is_equal("Hello.")


func test_fill_text_of_empty_text_is_empty() -> void:
	assert_that(WeavlyTextUtils.fill_text([], _make_engine())).is_equal("")


func test_fill_text_evaluates_arithmetic() -> void:
	var engine: WeavlyEngine = _make_engine()
	declare_variable(engine, "price", 3.5)
	var segments: Array = _segments(
		["Costs ", {"op": "*", "left": {"variable": "price"}, "right": 2.0}, " gold."]
	)
	assert_that(WeavlyTextUtils.fill_text(segments, engine)).is_equal("Costs 7 gold.")


func test_fill_text_evaluates_a_function_call() -> void:
	var engine: WeavlyEngine = _make_engine()
	declare_variable(engine, "hp", -4.0)
	var segments: Array = _segments([{"call": "max", "args": [{"variable": "hp"}, 0.0]}, " HP"])
	assert_that(WeavlyTextUtils.fill_text(segments, engine)).is_equal("0 HP")


func test_fill_text_fills_several_interpolations() -> void:
	var engine: WeavlyEngine = _engine_with_name()
	declare_variable(engine, "coins", 3.0)
	var segments: Array = _segments(
		[{"variable": "name"}, " has ", {"variable": "coins"}, {"variable": "name"}]
	)
	assert_that(WeavlyTextUtils.fill_text(segments, engine)).is_equal("Ada has 3Ada")


func test_fill_text_formats_a_bare_number_literal() -> void:
	assert_that(WeavlyTextUtils.fill_text(_segments([5.0]), _make_engine())).is_equal("5")


func test_fill_text_keeps_an_escaped_interpolation_literal() -> void:
	var text: String = WeavlyTextUtils.fill_text(["Write {$name}."], _engine_with_name())
	assert_that(text).is_equal("Write {$name}.")


func test_fill_text_reads_values_when_filled() -> void:
	var engine: WeavlyEngine = _engine_with_name()
	var segments: Array = _segments([{"variable": "name"}])
	assert_that(WeavlyTextUtils.fill_text(segments, engine)).is_equal("Ada")
	engine.variable_service.set_variable("name", "Bo")
	assert_that(WeavlyTextUtils.fill_text(segments, engine)).is_equal("Bo")


func test_fill_text_leaves_out_a_failing_interpolation_and_reports_it_once() -> void:
	var segments: Array = _segments(["Hi ", {"variable": "missing"}, "!"])
	assert_that(WeavlyTextUtils.fill_text(segments, _make_engine())).is_equal("Hi !")
	assert_logged(["Variable 'missing' isn't defined."])
