extends WeavlyTestSuite

# Declared functions against the compiler-built fixture in calls/src/calls.wvl.

const FIXTURE = "res://test/fixtures/integration/calls/build"

var _engine: WeavlyEngine
var _events: Array[String]
var _errors: Array[String]


func before_test() -> void:
	_events = []
	_errors = []
	_engine = WeavlyEngine.new()
	_engine.dialogue_path = FIXTURE
	add_child(auto_free(_engine))
	_engine.line_reached.connect(
		func(line: WeavlyModel.LineStatement) -> void:
			if line is WeavlyModel.NarrationLine:
				_events.append(line.text)
	)
	_engine.runtime_error.connect(
		func(message: String, _source: String, line: int) -> void:
			_errors.append("%d: %s" % [line, message])
	)


func _register_all() -> void:
	_engine.register_function(
		"trust",
		func(from: String, to: String) -> int:
			_events.append("trust(%s, %s)" % [from, to])
			return 3
	)
	_engine.register_function("mood", func() -> bool: return true)
	_engine.register_function("greeting", func(name: String) -> String: return "Hi " + name)
	_engine.register_function("next_scene", func() -> String: return "other")
	_engine.register_function("region", func() -> String: return "city")
	_engine.register_function("partner", func() -> String: return "bob")
	_engine.register_function(
		"shout",
		func(text: String, volume: float) -> void: _events.append("shout(%s, %s)" % [text, volume])
	)
	_engine.register_function("wave", func() -> void: _events.append("wave"))


func _run(node_id: String) -> void:
	_engine.start(node_id)
	while _engine.is_running():
		_engine.next()


func _variable(id: String) -> Variant:
	return _engine.get_variable(id)


func test_functions_get_their_arguments_and_their_results_are_used() -> void:
	_register_all()
	_run("start")
	assert_that(_variable("score")).is_equal(3.0)
	assert_array(_events).is_equal(
		["trust(ann, start)", "Happy.", "Hi Ann is here.", "shout(hey, 3.0)", "wave", "Done."]
	)


func test_name_results_are_stored_as_names() -> void:
	_register_all()
	_run("start")
	assert_that(_variable("scene")).is_equal("other")
	assert_that(_variable("area")).is_equal("city")
	assert_that(_variable("seat")).is_equal("bob")


func test_a_meta_value_can_call_a_function() -> void:
	_register_all()
	assert_that(_engine.get_node_meta("start", "cost")).is_equal(4.0)


func test_the_first_use_reports_everything_not_registered_once() -> void:
	_engine.register_function("trust", func(_from: String, _to: String) -> float: return 1.0)
	_engine.list_pool(["city"])
	_engine.peek_pool(["city"])
	(
		assert_array(_errors)
		. is_equal(
			[
				"0: Function 'mood' is declared, but no callable is registered for it.",
				"0: Function 'greeting' is declared, but no callable is registered for it.",
				"0: Function 'next_scene' is declared, but no callable is registered for it.",
				"0: Function 'region' is declared, but no callable is registered for it.",
				"0: Function 'partner' is declared, but no callable is registered for it.",
				"0: Function 'shout' is declared, but no callable is registered for it.",
				"0: Function 'wave' is declared, but no callable is registered for it.",
			]
		)
	)
	assert_logged(["mood", "greeting", "next_scene", "region", "partner", "shout", "wave"])


func test_a_missing_function_fails_its_expression_at_the_call() -> void:
	_register_all()
	_engine.function_service._callables.erase("mood")
	_run("start")
	assert_bool(_events.has("Happy.")).is_false()
	(
		assert_array(_errors)
		. contains(
			[
				"26: Can't call function 'mood' because no callable is registered for it.",
				"35: Can't call function 'mood' because no callable is registered for it.",
			]
		)
	)
	assert_logged(["mood", "mood", "mood"])


func test_a_result_of_the_wrong_type_is_reported_in_an_expression_and_a_do_statement() -> void:
	_register_all()
	_engine.register_function("mood", func() -> int: return 1)
	_run("start")
	assert_bool(_events.has("Happy.")).is_false()
	(
		assert_array(_errors)
		. is_equal(
			[
				"26: Function 'mood' returned a value of type 'int' instead of a bool.",
				"35: Function 'mood' returned a value of type 'int' instead of a bool.",
			]
		)
	)
	assert_logged(["mood", "mood"])


func test_a_value_returned_by_a_function_without_a_result_is_ignored() -> void:
	_register_all()
	_engine.register_function(
		"wave",
		func() -> int:
			_events.append("wave")
			return 1
	)
	_run("start")
	assert_bool(_events.has("wave")).is_true()
	assert_array(_errors).is_empty()


func test_a_result_naming_no_declared_node_is_rejected() -> void:
	_register_all()
	_engine.register_function("next_scene", func() -> String: return "nowhere")
	_run("start")
	assert_that(_variable("scene")).is_equal("start")
	assert_array(_errors).is_equal(
		["32: Function 'next_scene' returned 'nowhere', but no node has that name."]
	)
	assert_logged(["nowhere"])


func test_a_do_statement_without_a_callable_is_reported_and_skipped() -> void:
	_register_all()
	_engine.function_service._callables.erase("wave")
	_run("start")
	assert_bool(_events.has("wave")).is_false()
	assert_str(_events.back()).is_equal("Done.")
	assert_array(_errors).contains(
		["31: Can't call function 'wave' because no callable is registered for it."]
	)
	assert_logged(["wave", "wave"])


func test_registering_an_undeclared_name_is_an_error() -> void:
	_engine.register_function("luck", func() -> float: return 1.0)
	assert_array(_engine.function_service.get_unregistered()).contains(["mood"])
	assert_logged(["Can't register function 'luck' because it isn't declared."])


func test_registering_a_callable_with_the_wrong_argument_count_is_an_error() -> void:
	_engine.register_function("trust", func(from: String) -> String: return from)
	_engine.register_function("wave", func(_how: String) -> void: pass)
	assert_array(_engine.function_service.get_unregistered()).contains(["trust", "wave"])
	assert_logged(
		[
			"Can't register function 'trust' because it takes 1 instead of 2 arguments.",
			"Can't register function 'wave' because it takes 1 instead of 0 arguments.",
		]
	)


func test_registering_again_replaces_the_callable() -> void:
	_register_all()
	_engine.register_function("greeting", func(name: String) -> String: return "Bye " + name)
	_run("start")
	assert_bool(_events.has("Bye Ann is here.")).is_true()


func test_render_returns_do_statements_and_run_do_calls_their_function() -> void:
	_register_all()
	var entries: Array[WeavlyModel.Statement] = _engine.render("start")
	assert_bool(_events.has("wave")).is_false()
	for entry: WeavlyModel.Statement in entries:
		if entry is WeavlyModel.DoStatement:
			_engine.run_do(entry)
	(
		assert_array(_events.filter(func(event: String) -> bool: return not event.ends_with(".")))
		. is_equal(["trust(ann, start)", "shout(hey, 3.0)", "wave"])
	)
