extends GdUnitTestSuite

const Service = preload("res://addons/weavly/src/services/implementations/default_line_service.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	_service = Service.new()
	_service.initialize(_engine)


# =====================
# execute_narration_line
# =====================


func test_narration_line_pauses_statement_service() -> void:
	var line := WeavlyModel.NarrationLine.new(["hello"])
	_service.execute_narration_line(line)
	assert_bool(_engine.statement_service.is_paused()).is_true()


func test_narration_line_emits_signal() -> void:
	var line := WeavlyModel.NarrationLine.new(["hello"])
	monitor_signals(_service, false)
	_service.execute_narration_line(line)
	await assert_signal(_service).is_emitted(
		"executed_narration_line", [WeavlyTextUtils.fill_narration_line(line, _engine)]
	)


# =====================
# execute_character_line
# =====================


func test_character_line_pauses_statement_service() -> void:
	var line := WeavlyModel.CharacterLine.new("Alice", false, ["hi"])
	_service.execute_character_line(line)
	assert_bool(_engine.statement_service.is_paused()).is_true()


func test_character_line_emits_signal() -> void:
	var line := WeavlyModel.CharacterLine.new("Alice", false, ["hi"])
	monitor_signals(_service, false)
	_service.execute_character_line(line)
	await assert_signal(_service).is_emitted(
		"executed_character_line", [WeavlyTextUtils.fill_character_line(line, _engine)]
	)
