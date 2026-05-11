extends GutTest

const FakeEngine = preload("res://test/helpers/fake_engine.gd")


func _make_engine() -> WeavlyEngine:
	return add_child_autofree(FakeEngine.new())


# =====================
# format_string_strip_quotes
# =====================


func test_strip_quotes_removes_surrounding_quotes() -> void:
	assert_eq(WeavlyTextUtils.format_string_strip_quotes("\"hi\""), "hi")


func test_strip_quotes_leaves_unquoted_string() -> void:
	assert_eq(WeavlyTextUtils.format_string_strip_quotes("hi"), "hi")


func test_strip_quotes_single_char_unchanged() -> void:
	assert_eq(WeavlyTextUtils.format_string_strip_quotes("\""), "\"")


func test_strip_quotes_non_string_unchanged() -> void:
	assert_eq(WeavlyTextUtils.format_string_strip_quotes(42), 42)


# =====================
# format_float_trim_zero
# =====================


func test_trim_zero_whole_float_returns_int() -> void:
	assert_eq(WeavlyTextUtils.format_float_trim_zero(5.0), 5)


func test_trim_zero_fractional_float_unchanged() -> void:
	assert_eq(WeavlyTextUtils.format_float_trim_zero(5.5), 5.5)


func test_trim_zero_non_float_unchanged() -> void:
	assert_eq(WeavlyTextUtils.format_float_trim_zero("hi"), "hi")


# =====================
# inject_variables
# =====================


func test_inject_single_variable() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("name", "Alice")
	assert_eq(WeavlyTextUtils.inject_variables("Hi {$name}", engine), "Hi Alice")


func test_inject_strips_string_quotes() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("greeting", "\"hello\"")
	assert_eq(WeavlyTextUtils.inject_variables("{$greeting}", engine), "hello")


func test_inject_trims_float_zero() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("score", 10.0)
	assert_eq(WeavlyTextUtils.inject_variables("You have {$score}", engine), "You have 10")


func test_inject_multiple_variables() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("a", 1.0)
	engine.variable_service.set_variable("b", 2.0)
	assert_eq(WeavlyTextUtils.inject_variables("{$a} and {$b}", engine), "1 and 2")


func test_inject_no_match_returns_verbatim() -> void:
	assert_eq(WeavlyTextUtils.inject_variables("no vars here", _make_engine()), "no vars here")


func test_inject_custom_pipeline_applied() -> void:
	var engine = _make_engine()
	engine.variable_service.set_variable("name", "Alice")
	var upper_pipeline: Array[Callable] = [func(v: Variant) -> Variant: return str(v).to_upper()]
	assert_eq(WeavlyTextUtils.inject_variables("{$name}", engine, upper_pipeline), "ALICE")
