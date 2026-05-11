extends GutTest

const _Service = preload("res://addons/weavly/src/services/implementations/list_line_service.gd")

var _service


func before_each() -> void:
	_service = _Service.new()
	_service.initialize(null)


# =====================
# execute_narration_line
# =====================


func test_narration_line_emits_signal() -> void:
	var line := WeavlyModel.NarrationLine.new("hello")
	watch_signals(_service)
	_service.execute_narration_line(line)
	assert_signal_emitted_with_parameters(_service, "executed_narration_line", [line])


# =====================
# execute_character_line
# =====================


func test_character_line_emits_signal() -> void:
	var line := WeavlyModel.CharacterLine.new("Alice", false, "hi")
	watch_signals(_service)
	_service.execute_character_line(line)
	assert_signal_emitted_with_parameters(_service, "executed_character_line", [line])
