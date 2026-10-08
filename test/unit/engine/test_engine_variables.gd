# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: FakeEngine


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	var body: Array[WeavlyModel.Statement] = []
	_engine.story.add_node(WeavlyModel.WeavlyNode.new("start", body))
	_engine.story.add_pool("city")
	_engine.story.add_slot("bob")


func _number(id: String, value: float, min: Variant = null, max: Variant = null) -> void:
	declare(_engine, WeavlyModel.NumberVariable.new(id, value, min, max))


func _extern(variable: WeavlyModel.Variable) -> void:
	variable.extern = true
	declare(_engine, variable)


# Each variable_changed as [id, value, old_value].
func _record_changes() -> Array[Array]:
	var changed: Array[Array] = []
	_engine.variable_changed.connect(
		func(id: String, value: Variant, old_value: Variant) -> void:
			changed.append([id, value, old_value])
	)
	return changed


func _load(values: Dictionary) -> void:
	_engine.set_state({"version": WeavlyEngine.STATE_VERSION, "services": {"variable": values}})


# =====================
# get / set
# =====================


func test_set_and_get_each_type() -> void:
	_number("score", 0.0)
	declare_variable(_engine, "name", "Ada")
	declare_variable(_engine, "active", false)
	_engine.set_variable("score", 42.0)
	_engine.set_variable("name", "Bo")
	_engine.set_variable("active", true)
	assert_that(_engine.get_variable("score")).is_equal(42.0)
	assert_that(_engine.get_variable("name")).is_equal("Bo")
	assert_that(_engine.get_variable("active")).is_equal(true)


func test_getting_an_undeclared_variable_is_reported() -> void:
	assert_that(_engine.get_variable("missing")).is_null()
	assert_logged(["Variable 'missing' isn't defined."])


func test_set_emits_the_new_and_old_value() -> void:
	_number("health", 5.0)
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("health", 7.0)
	_engine.set_variable("health", 4.0)
	assert_array(changed).is_equal([["health", 7.0, 5.0], ["health", 4.0, 7.0]])


func test_setting_the_same_value_emits_nothing() -> void:
	declare_variable(_engine, "name", "Ada")
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("name", "Ada")
	assert_array(changed).is_empty()


func test_set_accepts_an_int_for_a_number() -> void:
	_number("score", 10.0)
	_engine.set_variable("score", 5)
	assert_int(typeof(_engine.variable_service.get_value("score"))).is_equal(TYPE_FLOAT)
	assert_that(_engine.get_variable("score")).is_equal(5.0)


func test_setting_an_undeclared_variable_is_rejected() -> void:
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("gold", 3.0)
	assert_bool(_engine.variable_service.has("gold")).is_false()
	assert_array(changed).is_empty()
	assert_logged(["Can't set variable 'gold' because it isn't declared."])


# =====================
# Number ranges
# =====================


func test_a_number_is_clamped_to_its_range() -> void:
	_number("health", 50.0, 0.0, 100.0)
	_engine.set_variable("health", -10.0)
	assert_that(_engine.get_variable("health")).is_equal(0.0)
	_engine.set_variable("health", 150.0)
	assert_that(_engine.get_variable("health")).is_equal(100.0)
	_engine.set_variable("health", 75.0)
	assert_that(_engine.get_variable("health")).is_equal(75.0)


func test_a_clamped_change_emits_the_clamped_value() -> void:
	_number("health", 50.0, 0.0, null)
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("health", -5.0)
	assert_array(changed).is_equal([["health", 0.0, 50.0]])


func test_a_change_clamped_to_the_current_value_emits_nothing() -> void:
	_number("health", 100.0, 0.0, 100.0)
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("health", 120.0)
	assert_array(changed).is_empty()


# =====================
# Type and name checks on writes
# =====================


func test_a_value_of_the_wrong_type_keeps_the_value_and_emits_nothing() -> void:
	_number("score", 10.0)
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("score", "high")
	assert_that(_engine.get_variable("score")).is_equal(10.0)
	assert_array(changed).is_empty()
	assert_logged(
		["Can't set variable 'score' to a value of type 'String' because it's a number."]
	)


func test_a_wrong_write_reaches_runtime_error() -> void:
	declare_variable(_engine, "has_key", false)
	var errors: Array[String] = []
	_engine.runtime_error.connect(
		func(message: String, _source: String, _line: int) -> void: errors.append(message)
	)
	_engine.set_variable("has_key", 1.0)
	assert_logged(["Can't set variable 'has_key' to a value of type 'float' because it's a bool."])
	assert_array(errors).is_equal(
		["Can't set variable 'has_key' to a value of type 'float' because it's a bool."]
	)


func test_a_name_variable_accepts_a_declared_name_of_its_type() -> void:
	declare(_engine, WeavlyModel.NameVariable.new("next", "node", "start"))
	declare(_engine, WeavlyModel.NameVariable.new("region", "pool", "city"))
	declare(_engine, WeavlyModel.NameVariable.new("partner", "slot", "bob"))
	_engine.story.add_node(WeavlyModel.WeavlyNode.new("end", []))
	_engine.set_variable("next", "end")
	assert_that(_engine.get_variable("next")).is_equal("end")


func test_a_name_variable_rejects_a_name_that_isnt_declared_for_its_type() -> void:
	declare(_engine, WeavlyModel.NameVariable.new("next", "node", "start"))
	declare(_engine, WeavlyModel.NameVariable.new("region", "pool", "city"))
	declare(_engine, WeavlyModel.NameVariable.new("partner", "slot", "bob"))
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("next", "city")
	_engine.set_variable("region", "bob")
	_engine.set_variable("partner", "start")
	assert_that(_engine.get_variable("next")).is_equal("start")
	assert_array(changed).is_empty()
	assert_logged(
		[
			"Can't set variable 'next' to 'city' because no node has that name.",
			"Can't set variable 'region' to 'bob' because no pool has that name.",
			"Can't set variable 'partner' to 'start' because no slot has that name.",
		]
	)


func test_a_name_variable_rejects_a_value_of_another_type() -> void:
	declare(_engine, WeavlyModel.NameVariable.new("region", "pool", "city"))
	_engine.set_variable("region", 3.0)
	assert_logged(["Can't set variable 'region' to a value of type 'float' because it's a pool."])


# =====================
# Externs
# =====================


func test_an_extern_has_no_value_until_the_game_sets_it() -> void:
	_extern(WeavlyModel.NumberVariable.new("reputation", 0.0, null, null))
	assert_bool(_engine.variable_service.has("reputation")).is_false()
	assert_that(_engine.get_variable("reputation")).is_null()
	assert_logged(["Variable 'reputation' is declared extern but was never defined."])
	_engine.set_variable("reputation", 3.0)
	assert_that(_engine.get_variable("reputation")).is_equal(3.0)


func test_the_first_set_of_an_extern_has_no_old_value() -> void:
	_extern(WeavlyModel.NumberVariable.new("reputation", 0.0, null, null))
	var changed: Array[Array] = _record_changes()
	_engine.set_variable("reputation", 3.0)
	_engine.set_variable("reputation", 5.0)
	assert_array(changed).is_equal([["reputation", 3.0, null], ["reputation", 5.0, 3.0]])


func test_an_extern_of_the_wrong_type_is_rejected() -> void:
	_extern(WeavlyModel.NumberVariable.new("reputation", 0.0, null, null))
	_engine.set_variable("reputation", "high")
	assert_logged(
		["Can't set variable 'reputation' to a value of type 'String' because it's a number."]
	)
	assert_bool(_engine.variable_service.has("reputation")).is_false()


func test_an_extern_name_variable_takes_a_declared_name() -> void:
	_extern(WeavlyModel.NameVariable.new("home", "pool", ""))
	_engine.set_variable("home", "city")
	assert_that(_engine.get_variable("home")).is_equal("city")


# =====================
# Checked reads
# =====================


func test_a_stored_value_of_the_wrong_type_is_reported_on_read() -> void:
	_number("score", 0.0)
	_engine.variable_service.set_value("score", "high")
	assert_that(_engine.get_variable("score")).is_null()
	assert_logged(["Variable 'score' holds a value of type 'String' instead of a number."])


func test_a_stored_name_that_isnt_declared_is_reported_on_read() -> void:
	declare(_engine, WeavlyModel.NameVariable.new("region", "pool", "city"))
	_engine.variable_service.set_value("region", "harbor")
	assert_that(_engine.get_variable("region")).is_null()
	assert_logged(["Variable 'region' holds 'harbor', but no pool has that name."])


func test_a_stored_int_is_read_as_a_number() -> void:
	_number("score", 0.0)
	_engine.variable_service.set_value("score", 3)
	var value: Variant = _engine.get_variable("score")
	assert_int(typeof(value)).is_equal(TYPE_FLOAT)
	assert_that(value).is_equal(3.0)


# =====================
# Saving and loading
# =====================


func test_get_state_holds_the_story_owned_values() -> void:
	_number("score", 3.0)
	declare_variable(_engine, "name", "Ada")
	_extern(WeavlyModel.NumberVariable.new("reputation", 0.0, null, null))
	_engine.set_variable("reputation", 4.0)
	assert_that(_engine.get_state()["services"]["variable"]).is_equal(
		{"score": 3.0, "name": "Ada"}
	)


func test_loading_restores_values_without_emitting() -> void:
	_number("score", 3.0)
	var changed: Array[Array] = _record_changes()
	_load({"score": 8.0})
	assert_that(_engine.get_variable("score")).is_equal(8.0)
	assert_array(changed).is_empty()


func test_loading_gives_variables_missing_from_the_state_their_default() -> void:
	_number("score", 3.0)
	declare_variable(_engine, "added_later", true)
	_engine.set_variable("score", 5.0)
	_engine.set_variable("added_later", false)
	_load({"score": 8.0})
	assert_that(_engine.get_variable("score")).is_equal(8.0)
	assert_that(_engine.get_variable("added_later")).is_equal(true)


func test_loading_clamps_numbers_and_resets_values_of_the_wrong_type() -> void:
	_number("score", 3.0, 0.0, 10.0)
	declare_variable(_engine, "flag", false)
	_load({"score": 50.0, "flag": "yes"})
	assert_that(_engine.get_variable("score")).is_equal(10.0)
	assert_that(_engine.get_variable("flag")).is_equal(false)
	assert_logged(
		[], ["Saved variable 'flag' is skipped because it holds a 'String' instead of a bool."]
	)


func test_loading_resets_a_saved_name_that_no_longer_exists() -> void:
	declare(_engine, WeavlyModel.NameVariable.new("region", "pool", "city"))
	_load({"region": "harbor"})
	assert_that(_engine.get_variable("region")).is_equal("city")
	assert_logged(
		[], ["Saved variable 'region' is skipped because pool 'harbor' no longer exists."]
	)


func test_loading_keeps_an_extern_and_ignores_a_saved_one() -> void:
	_extern(WeavlyModel.NumberVariable.new("reputation", 0.0, null, null))
	_engine.set_variable("reputation", 4.0)
	_load({"reputation": 2.0})
	assert_that(_engine.get_variable("reputation")).is_equal(4.0)


func test_loading_leaves_an_undefined_extern_undefined() -> void:
	_extern(WeavlyModel.NumberVariable.new("reputation", 0.0, null, null))
	_load({"reputation": 2.0})
	assert_bool(_engine.variable_service.has("reputation")).is_false()
