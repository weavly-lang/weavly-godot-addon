extends GutTest

const _Service = preload(
	"res://addons/weavly/src/services/implementations/default_variable_service.gd"
)

var _service


func before_each() -> void:
	_service = _Service.new()
	_service.initialize(null)


# =====================
# add / get
# =====================


func test_add_and_get_number_variable() -> void:
	var v := WeavlyModel.NumberVariable.new(&"score", 5.0, null, null)
	_service.add_variable(v)
	assert_eq(_service.get_variable("score"), 5.0)


func test_add_and_get_string_variable() -> void:
	var v := WeavlyModel.StringVariable.new(&"name", "Alice")
	_service.add_variable(v)
	assert_eq(_service.get_variable("name"), "Alice")


func test_add_and_get_flag_variable() -> void:
	var v := WeavlyModel.FlagVariable.new(&"active", false)
	_service.add_variable(v)
	assert_eq(_service.get_variable("active"), false)


func test_get_missing_returns_default() -> void:
	assert_null(_service.get_variable("missing"))
	assert_engine_error(1)


# =====================
# set
# =====================


func test_set_variable_updates_value() -> void:
	var v := WeavlyModel.NumberVariable.new(&"score", 0.0, null, null)
	_service.add_variable(v)
	_service.set_variable("score", 42.0)
	assert_eq(_service.get_variable("score"), 42.0)


func test_set_variable_emits_signal() -> void:
	var v := WeavlyModel.NumberVariable.new(&"score", 0.0, null, null)
	_service.add_variable(v)
	watch_signals(_service)
	_service.set_variable("score", 10.0)
	assert_signal_emitted_with_parameters(_service, "variable_changed", ["score", 10.0])


# =====================
# number clamping
# =====================


func test_number_min_clamp() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, 0.0, null)
	_service.add_variable(v)
	_service.set_variable("health", -10.0)
	assert_eq(_service.get_variable("health"), 0.0)


func test_number_max_clamp() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, null, 100.0)
	_service.add_variable(v)
	_service.set_variable("health", 150.0)
	assert_eq(_service.get_variable("health"), 100.0)


func test_number_min_clamp_emits_clamped_value() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, 0.0, null)
	_service.add_variable(v)
	watch_signals(_service)
	_service.set_variable("health", -5.0)
	assert_signal_emitted_with_parameters(_service, "variable_changed", ["health", 0.0])


func test_number_within_range_is_unchanged() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, 0.0, 100.0)
	_service.add_variable(v)
	_service.set_variable("health", 75.0)
	assert_eq(_service.get_variable("health"), 75.0)


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	var first := WeavlyModel.NumberVariable.new(&"score", 1.0, null, null)
	var second := WeavlyModel.NumberVariable.new(&"score", 2.0, null, null)
	_service.add_variable(first)
	_service.add_variable(second)
	assert_engine_error(1)
	assert_eq(_service.get_variable("score"), 1.0)
