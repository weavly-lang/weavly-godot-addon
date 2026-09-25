# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_variable_service.gd"
)

var _service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get
# =====================


func test_add_and_get_number_variable() -> void:
	var v := WeavlyModel.NumberVariable.new(&"score", 5.0, null, null)
	_service.add_variable(v)
	assert_that(_service.get_variable("score")).is_equal(5.0)


func test_add_and_get_string_variable() -> void:
	var v := WeavlyModel.StringVariable.new(&"name", "Alice")
	_service.add_variable(v)
	assert_that(_service.get_variable("name")).is_equal("Alice")


func test_add_and_get_flag_variable() -> void:
	var v := WeavlyModel.FlagVariable.new(&"active", false)
	_service.add_variable(v)
	assert_that(_service.get_variable("active")).is_equal(false)


func test_get_missing_returns_default() -> void:
	assert_that(_service.get_variable("missing")).is_null()
	assert_logged([], ["Variable with id 'missing' doesn't exist"])


# =====================
# set
# =====================


func test_set_variable_updates_value() -> void:
	var v := WeavlyModel.NumberVariable.new(&"score", 0.0, null, null)
	_service.add_variable(v)
	_service.set_variable("score", 42.0)
	assert_that(_service.get_variable("score")).is_equal(42.0)


func test_set_variable_emits_signal() -> void:
	var v := WeavlyModel.NumberVariable.new(&"score", 0.0, null, null)
	_service.add_variable(v)
	monitor_signals(_service, false)
	_service.set_variable("score", 10.0)
	await assert_signal(_service).is_emitted("variable_changed", ["score", 10.0])


# =====================
# number clamping
# =====================


func test_number_min_clamp() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, 0.0, null)
	_service.add_variable(v)
	_service.set_variable("health", -10.0)
	assert_that(_service.get_variable("health")).is_equal(0.0)


func test_number_max_clamp() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, null, 100.0)
	_service.add_variable(v)
	_service.set_variable("health", 150.0)
	assert_that(_service.get_variable("health")).is_equal(100.0)


func test_number_min_clamp_emits_clamped_value() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, 0.0, null)
	_service.add_variable(v)
	monitor_signals(_service, false)
	_service.set_variable("health", -5.0)
	await assert_signal(_service).is_emitted("variable_changed", ["health", 0.0])


func test_number_within_range_is_unchanged() -> void:
	var v := WeavlyModel.NumberVariable.new(&"health", 50.0, 0.0, 100.0)
	_service.add_variable(v)
	_service.set_variable("health", 75.0)
	assert_that(_service.get_variable("health")).is_equal(75.0)


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	var first := WeavlyModel.NumberVariable.new(&"score", 1.0, null, null)
	var second := WeavlyModel.NumberVariable.new(&"score", 2.0, null, null)
	_service.add_variable(first)
	_service.add_variable(second)
	assert_logged([], ["Variable with id 'score' already exists."])
	assert_that(_service.get_variable("score")).is_equal(1.0)


# =====================
# type checks
# =====================


func test_set_variable_with_the_wrong_type_keeps_the_value() -> void:
	_service.add_variable(WeavlyModel.NumberVariable.new(&"score", 10.0, 0.0, 100.0))
	_service.set_variable("score", "high")
	assert_that(_service.get_variable("score")).is_equal(10.0)
	assert_logged(
		["Can't set variable 'score' to a value of type 'String' because it's a number."]
	)


func test_set_variable_with_the_wrong_type_emits_nothing() -> void:
	_service.add_variable(WeavlyModel.FlagVariable.new(&"has_key", false))
	monitor_signals(_service, false)
	_service.set_variable("has_key", 1.0)
	assert_logged(["Can't set variable 'has_key' to a value of type 'float' because it's a flag."])
	await assert_signal(_service).is_not_emitted("variable_changed")


func test_set_variable_accepts_an_int_for_a_number() -> void:
	_service.add_variable(WeavlyModel.NumberVariable.new(&"score", 10.0, null, null))
	_service.set_variable("score", 5)
	assert_that(_service.get_variable("score")).is_equal(5.0)


func test_set_variable_of_an_undeclared_variable_is_rejected() -> void:
	var changes: Array = []
	_service.variable_changed.connect(
		func(id: String, _value: Variant) -> void: changes.append(id)
	)
	_service.set_variable("gold", 3.0)
	assert_bool(_service.has("gold")).is_false()
	assert_object(_service.get_declaration("gold")).is_null()
	assert_that(changes).is_empty()
	assert_logged(["Can't set variable 'gold' because it isn't declared."])


# =====================
# extern declarations
# =====================


func _add_extern(id: StringName) -> void:
	var variable: WeavlyModel.NumberVariable = WeavlyModel.NumberVariable.new(id, 0.0, null, null)
	variable.extern = true
	_service.add_variable(variable)


func test_an_extern_declaration_has_no_value() -> void:
	_add_extern(&"reputation")
	assert_bool(_service.has("reputation")).is_false()
	assert_bool(_service.get_declaration("reputation").extern).is_true()
	assert_that(_service.get_all_ids()).is_empty()


func test_game_code_defines_an_extern_variable() -> void:
	_add_extern(&"reputation")
	_service.set_variable("reputation", 3.0)
	assert_that(_service.get_variable("reputation")).is_equal(3.0)


func test_game_code_setting_an_extern_to_the_wrong_type_is_rejected() -> void:
	_add_extern(&"reputation")
	_service.set_variable("reputation", "high")
	assert_logged(
		["Can't set variable 'reputation' to a value of type 'String' because it's a number."]
	)
	assert_bool(_service.has("reputation")).is_false()


func test_adding_a_variable_defines_a_matching_extern() -> void:
	_add_extern(&"reputation")
	_service.add_variable(WeavlyModel.NumberVariable.new(&"reputation", 4.0, 0.0, 10.0))
	assert_that(_service.get_variable("reputation")).is_equal(4.0)
	assert_bool(_service.get_declaration("reputation").extern).is_false()


func test_adding_a_variable_of_another_type_for_an_extern_is_rejected() -> void:
	_add_extern(&"reputation")
	_service.add_variable(WeavlyModel.StringVariable.new(&"reputation", "high"))
	assert_logged(["Variable 'reputation' is a string, but it's declared extern as a number."])
	assert_bool(_service.has("reputation")).is_false()


func test_get_declaration_of_an_unknown_name_is_null() -> void:
	assert_object(_service.get_declaration("missing")).is_null()


# =====================
# get_state / set_state
# =====================


func test_get_state_holds_values_only() -> void:
	_service.add_variable(WeavlyModel.NumberVariable.new(&"score", 3.0, 0.0, 10.0))
	_service.add_variable(WeavlyModel.StringVariable.new(&"name", "Ada"))
	assert_that(_service.get_state()).is_equal({"score": 3.0, "name": "Ada"})


func test_set_state_restores_values_without_emitting() -> void:
	_service.add_variable(WeavlyModel.NumberVariable.new(&"score", 3.0, null, null))
	monitor_signals(_service, false)
	_service.set_state({"score": 8.0})
	assert_that(_service.get_variable("score")).is_equal(8.0)
	await assert_signal(_service).is_not_emitted("variable_changed")


func test_set_state_gives_variables_missing_from_it_their_default() -> void:
	_service.add_variable(WeavlyModel.NumberVariable.new(&"score", 3.0, null, null))
	_service.add_variable(WeavlyModel.FlagVariable.new(&"added_later", true))
	_service.set_variable("score", 5.0)
	_service.set_variable("added_later", false)
	_service.set_state({"score": 8.0})
	assert_that(_service.get_variable("score")).is_equal(8.0)
	assert_that(_service.get_variable("added_later")).is_equal(true)


func test_set_state_skips_a_variable_that_no_longer_exists() -> void:
	_service.set_state({"gone": 1.0})
	assert_bool(_service.has("gone")).is_false()
	assert_logged([], ["Saved variable 'gone' no longer exists, skipping it."])


func test_set_state_checks_types_and_clamps() -> void:
	_service.add_variable(WeavlyModel.NumberVariable.new(&"score", 3.0, 0.0, 10.0))
	_service.add_variable(WeavlyModel.FlagVariable.new(&"flag", false))
	_service.set_state({"score": 50.0, "flag": "yes"})
	assert_that(_service.get_variable("score")).is_equal(10.0)
	assert_that(_service.get_variable("flag")).is_equal(false)
	assert_logged(["Can't set variable 'flag' to a value of type 'String' because it's a flag."])


func test_set_state_leaves_an_extern_undefined_unless_saved() -> void:
	var variable: WeavlyModel.NumberVariable = WeavlyModel.NumberVariable.new(
		&"reputation", 0.0, null, null
	)
	variable.extern = true
	_service.add_variable(variable)
	_service.set_variable("reputation", 4.0)
	_service.set_state({})
	assert_bool(_service.has("reputation")).is_false()
	_service.set_state({"reputation": 2.0})
	assert_that(_service.get_variable("reputation")).is_equal(2.0)
