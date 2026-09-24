# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")


func _make_engine() -> WeavlyEngine:
	var engine: WeavlyEngine = auto_free(FakeEngine.new())
	add_child(engine)
	return engine


# =====================
# format_string_strip_quotes
# =====================


func test_strip_quotes_removes_surrounding_quotes() -> void:
	assert_that(WeavlyTextUtils.format_string_strip_quotes('"hi"')).is_equal("hi")


func test_strip_quotes_leaves_unquoted_string() -> void:
	assert_that(WeavlyTextUtils.format_string_strip_quotes("hi")).is_equal("hi")


func test_strip_quotes_single_char_unchanged() -> void:
	assert_that(WeavlyTextUtils.format_string_strip_quotes('"')).is_equal('"')


func test_strip_quotes_non_string_unchanged() -> void:
	assert_that(WeavlyTextUtils.format_string_strip_quotes(42)).is_equal(42)


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
	var engine = _make_engine()
	engine.variable_service.set_variable("gold", 1000000.5)
	assert_that(WeavlyTextUtils.inject_variables("{$gold}", engine)).is_equal("1000000.5")


func test_trim_zero_non_float_unchanged() -> void:
	assert_that(WeavlyTextUtils.format_float_trim_zero("hi")).is_equal("hi")


# =====================
# inject_variables
# =====================


func test_inject_single_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("name", "Alice")
	assert_that(WeavlyTextUtils.inject_variables("Hi {$name}", engine)).is_equal("Hi Alice")


func test_inject_keeps_quotes_that_are_part_of_the_value() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("greeting", '"hello"')
	assert_that(WeavlyTextUtils.inject_variables("{$greeting}", engine)).is_equal('"hello"')


func test_inject_trims_float_zero() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("score", 10.0)
	assert_that(WeavlyTextUtils.inject_variables("You have {$score}", engine)).is_equal(
		"You have 10"
	)


func test_inject_rounds_decimals() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("third", 1.0 / 3.0)
	engine.variable_service.set_variable("sum", 0.1 + 0.2)
	engine.variable_service.set_variable("half", 2.5)
	assert_that(WeavlyTextUtils.inject_variables("{$third} {$sum} {$half}", engine)).is_equal(
		"0.33 0.3 2.5"
	)


func test_inject_multiple_variables() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("a", 1.0)
	engine.variable_service.set_variable("b", 2.0)
	assert_that(WeavlyTextUtils.inject_variables("{$a} and {$b}", engine)).is_equal("1 and 2")


func test_inject_no_match_returns_verbatim() -> void:
	assert_that(WeavlyTextUtils.inject_variables("no vars here", _make_engine())).is_equal(
		"no vars here"
	)


func test_inject_custom_pipeline_applied() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("name", "Alice")
	var upper_pipeline: Array[Callable] = [func(v: Variant) -> Variant: return str(v).to_upper()]
	assert_that(WeavlyTextUtils.inject_variables("{$name}", engine, upper_pipeline)).is_equal(
		"ALICE"
	)


func test_inject_keeps_an_unknown_variable_and_reports_it_once() -> void:
	var text: String = WeavlyTextUtils.inject_variables(
		"{$missing} and {$missing}", _make_engine()
	)
	assert_that(text).is_equal("{$missing} and {$missing}")
	assert_logged(["Variable 'missing' isn't defined."])


# =====================
# fill_*
# =====================


func _engine_with_name() -> WeavlyEngine:
	var engine: WeavlyEngine = _make_engine()
	engine.variable_service.set_variable("name", "Ada")
	return engine


func test_fill_narration_line_copies_with_filled_text() -> void:
	var line: WeavlyModel.NarrationLine = WeavlyModel.NarrationLine.new("Hi {$name}")
	line.line = 4
	var filled: WeavlyModel.NarrationLine = WeavlyTextUtils.fill_narration_line(
		line, _engine_with_name()
	)
	assert_that(filled.text).is_equal("Hi Ada")
	assert_that(filled.raw_text).is_equal("Hi {$name}")
	assert_int(filled.line).is_equal(4)
	assert_that(line.text).is_equal("Hi {$name}")


func test_fill_character_line_resolves_a_name_that_is_an_id() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("name", true, "{$name}!")
	var filled: WeavlyModel.CharacterLine = WeavlyTextUtils.fill_character_line(
		line, _engine_with_name()
	)
	assert_that(filled.name).is_equal("Ada")
	assert_that(filled.raw_name).is_equal("name")
	assert_that(filled.text).is_equal("Ada!")
	assert_that(filled.raw_text).is_equal("{$name}!")


func test_fill_character_line_keeps_a_literal_name() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("name", false, "Hi")
	var filled: WeavlyModel.CharacterLine = WeavlyTextUtils.fill_character_line(
		line, _engine_with_name()
	)
	assert_that(filled.name).is_equal("name")


func test_fill_character_line_with_an_undefined_name_variable_reports_it() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("speaker", true, "Hi")
	var filled: WeavlyModel.CharacterLine = WeavlyTextUtils.fill_character_line(
		line, _make_engine()
	)
	assert_that(filled.name).is_equal("speaker")
	assert_logged(["Variable 'speaker' isn't defined."])


func test_fill_option_copies_with_filled_text() -> void:
	var body: Array[WeavlyModel.Statement] = []
	var option: WeavlyModel.Option = WeavlyModel.Option.new(
		WeavlyModel.TrueExpression.new(), "Ask {$name}", body, false
	)
	var filled: WeavlyModel.Option = WeavlyTextUtils.fill_option(option, _engine_with_name())
	assert_that(filled.text).is_equal("Ask Ada")
	assert_that(filled.raw_text).is_equal("Ask {$name}")
	assert_that(filled.body).is_same(option.body)
