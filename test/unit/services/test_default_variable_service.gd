extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _service: WeavlyDefaultVariableService


func before_test() -> void:
	var engine: FakeEngine = auto_free(FakeEngine.new())
	engine.story.add_variable(WeavlyModel.NumberVariable.new("score", 0.0, null, null))
	var reputation: WeavlyModel.NumberVariable = WeavlyModel.NumberVariable.new(
		"reputation", 0.0, null, null
	)
	reputation.extern = true
	engine.story.add_variable(reputation)
	_service = engine.variable_service


func test_keeps_the_value_it_is_given() -> void:
	assert_bool(_service.has("score")).is_false()
	_service.set_value("score", 4.0)
	assert_bool(_service.has("score")).is_true()
	assert_that(_service.get_value("score")).is_equal(4.0)


func test_get_state_leaves_externs_out() -> void:
	_service.set_value("score", 3.0)
	_service.set_value("reputation", 4.0)
	assert_that(_service.get_state()).is_equal({"score": 3.0})


func test_set_state_replaces_the_values_and_keeps_externs() -> void:
	_service.set_value("score", 3.0)
	_service.set_value("reputation", 4.0)
	_service.set_state({})
	assert_bool(_service.has("score")).is_false()
	assert_that(_service.get_value("reputation")).is_equal(4.0)


func test_set_state_ignores_a_saved_extern() -> void:
	_service.set_state({"score": 8.0, "reputation": 2.0})
	assert_that(_service.get_value("score")).is_equal(8.0)
	assert_bool(_service.has("reputation")).is_false()


func test_set_state_skips_a_variable_that_no_longer_exists() -> void:
	_service.set_state({"gone": 1.0})
	assert_bool(_service.has("gone")).is_false()
	assert_logged([], ["Saved variable 'gone' no longer exists, skipping it."])
