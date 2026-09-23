extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _reports: Array[Array]


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	_reports = []
	_engine.runtime_error.connect(
		func(message: String, source: String, line: int) -> void:
			_reports.append([message, source, line])
	)


func _node(source: String, line: int) -> WeavlyModel.WeavlyNode:
	var node: WeavlyModel.WeavlyNode = WeavlyModel.WeavlyNode.new("choices", [])
	node.source = source
	node.line = line
	return node


func test_report_error_prefixes_file_and_line() -> void:
	_engine.set_location(_node("story.wvl", 10))
	_engine.current_line = 12
	_engine.report_error("Variable 'x' isn't defined.")
	assert_logged(["story.wvl:12: error: Variable 'x' isn't defined."])
	assert_that(_reports).is_equal([["Variable 'x' isn't defined.", "story.wvl", 12]])


func test_report_warning_prefixes_file_and_line_without_emitting_runtime_error() -> void:
	_engine.set_location(_node("story.wvl", 10))
	_engine.current_line = 12
	_engine.report_warning("No option is available.")
	assert_logged([], ["story.wvl:12: warning: No option is available."])
	assert_that(_reports).is_empty()


func test_report_warning_without_a_line_names_file_and_node() -> void:
	_engine.set_location(_node("story.wvl", 0))
	_engine.report_warning("No option is available.")
	assert_logged([], ["story.wvl, node 'choices': warning: No option is available."])


func test_report_error_without_a_line_names_file_and_node() -> void:
	_engine.set_location(_node("story.wvl", 0))
	_engine.report_error("Variable 'x' isn't defined.")
	assert_logged(["story.wvl, node 'choices': error: Variable 'x' isn't defined."])


func test_report_error_without_a_source_names_the_node() -> void:
	_engine.set_location(_node("", 0))
	_engine.report_error("Variable 'x' isn't defined.")
	assert_logged(["node 'choices': error: Variable 'x' isn't defined."])


func test_report_error_without_a_location_reports_the_message() -> void:
	_engine.set_location(_node("story.wvl", 4))
	_engine.clear_location()
	_engine.report_error("Variable 'x' isn't defined.")
	assert_logged(["Variable 'x' isn't defined."])
	assert_that(_reports).is_equal([["Variable 'x' isn't defined.", "", 0]])
