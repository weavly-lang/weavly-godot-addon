extends WeavlyTestSuite

# Tracing statements, stepping with hold() and lines that don't wait.

const LINEAR_FIXTURE = "res://test/fixtures/integration/linear/build"
const NEVER_WAITING_LINE_SERVICE = "res://test/helpers/never_waiting_line_service.gd"

var _lines: Array[String]
var _entered: Array[String]


func before_test() -> void:
	_lines = []
	_entered = []


func _make_engine(custom_services: Array[Script] = []) -> WeavlyEngine:
	var engine: WeavlyEngine = WeavlyEngine.new()
	engine.dialogue_path = LINEAR_FIXTURE
	engine.custom_services = custom_services
	add_child(auto_free(engine))
	engine.line_reached.connect(
		func(line: WeavlyModel.LineStatement) -> void: _lines.append(line.text)
	)
	engine.entered_node.connect(func(id: String) -> void: _entered.append(id))
	return engine


func test_statement_reached_traces_every_statement_at_its_line() -> void:
	var engine: WeavlyEngine = _make_engine()
	var lines: Array[int] = []
	engine.statement_reached.connect(
		func(_statement: WeavlyModel.Statement) -> void: lines.append(engine.current_line)
	)
	engine.start("start")
	while engine.is_running():
		engine.next()
	assert_array(lines).is_equal([6, 7, 8, 9, 13, 14])


func test_a_hold_on_statement_reached_pauses_after_that_statement() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.statement_reached.connect(
		func(statement: WeavlyModel.Statement) -> void:
			if statement is WeavlyModel.SetStatement:
				engine.hold()
	)
	engine.start("start")
	engine.next()
	engine.next()
	assert_that(engine.get_variable("counter")).is_equal(7.0)
	assert_array(_entered).is_equal(["start"])
	engine.release()
	assert_array(_entered).is_equal(["start", "end"])
	assert_that(_lines.back()).is_equal("Goodbye")


func test_lines_a_line_service_doesnt_wait_on_are_passed_on_without_pausing() -> void:
	var engine: WeavlyEngine = _make_engine([load(NEVER_WAITING_LINE_SERVICE)])
	engine.start("start")
	assert_array(_lines).is_equal(["Welcome", "Hello", "Goodbye"])
	assert_bool(engine.is_running()).is_false()


func test_a_hold_released_inside_line_reached_keeps_the_line_waiting() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.line_reached.connect(
		func(_line: WeavlyModel.LineStatement) -> void:
			engine.hold()
			engine.release()
	)
	engine.start("start")
	assert_array(_lines).is_equal(["Welcome"])
	assert_bool(engine.is_running()).is_true()


func test_a_line_held_on_line_reached_waits_for_next_after_release() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.line_reached.connect(
		func(line: WeavlyModel.LineStatement) -> void:
			if line.text == "Welcome":
				engine.hold()
	)
	engine.start("start")
	engine.release()
	assert_array(_lines).is_equal(["Welcome"])
	engine.next()
	assert_array(_lines).is_equal(["Welcome", "Hello"])
