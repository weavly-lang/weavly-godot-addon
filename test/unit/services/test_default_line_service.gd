extends GutTest

const _Service = preload("res://addons/weavly/src/services/implementations/default_line_service.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func before_each() -> void:
	_engine = add_child_autofree(FakeEngine.new())
	_service = _Service.new()
	_service.initialize(_engine)


# =====================
# execute_narration_line
# =====================


func test_narration_line_pauses_statement_service() -> void:
	var line := WeavlyModel.NarrationLine.new("hello")
	_service.execute_narration_line(line)
	assert_true(_engine.statement_service.is_paused())


func test_narration_line_emits_signal() -> void:
	var line := WeavlyModel.NarrationLine.new("hello")
	watch_signals(_service)
	_service.execute_narration_line(line)
	assert_signal_emitted_with_parameters(_service, "executed_narration_line", [line])


# =====================
# execute_character_line
# =====================


func test_character_line_pauses_statement_service() -> void:
	var line := WeavlyModel.CharacterLine.new("Alice", false, "hi")
	_service.execute_character_line(line)
	assert_true(_engine.statement_service.is_paused())


func test_character_line_emits_signal() -> void:
	var line := WeavlyModel.CharacterLine.new("Alice", false, "hi")
	watch_signals(_service)
	_service.execute_character_line(line)
	assert_signal_emitted_with_parameters(_service, "executed_character_line", [line])
