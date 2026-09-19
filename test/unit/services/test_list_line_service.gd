extends GdUnitTestSuite

const Service = preload("res://addons/weavly/src/services/implementations/list_line_service.gd")

var _service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# execute_narration_line
# =====================


func test_narration_line_emits_signal() -> void:
	var line := WeavlyModel.NarrationLine.new("hello")
	monitor_signals(_service, false)
	_service.execute_narration_line(line)
	await assert_signal(_service).is_emitted("executed_narration_line", [line])


# =====================
# execute_character_line
# =====================


func test_character_line_emits_signal() -> void:
	var line := WeavlyModel.CharacterLine.new("Alice", false, "hi")
	monitor_signals(_service, false)
	_service.execute_character_line(line)
	await assert_signal(_service).is_emitted("executed_character_line", [line])
