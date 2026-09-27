extends GdUnitTestSuite

const Service = preload("res://addons/weavly/src/services/implementations/default_line_service.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service: Service


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	_service = Service.new()
	_service.initialize(_engine)


# =====================
# execute_narration_line
# =====================


func test_narration_line_pauses_statement_service() -> void:
	var line: WeavlyModel.NarrationLine = WeavlyModel.NarrationLine.new(["hello"])
	_service.execute_narration_line(line)
	assert_bool(_engine.statement_service.is_paused()).is_true()


func test_narration_line_emits_signal() -> void:
	var line: WeavlyModel.NarrationLine = WeavlyModel.NarrationLine.new(["hello"])
	var executed: Array[WeavlyModel.NarrationLine] = []
	_service.executed_narration_line.connect(
		func(l: WeavlyModel.NarrationLine) -> void: executed.append(l)
	)
	_service.execute_narration_line(line)
	assert_array(executed).is_equal([WeavlyTextUtils.fill_narration_line(line, _engine)])


# =====================
# execute_character_line
# =====================


func test_character_line_pauses_statement_service() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("Alice", false, ["hi"])
	_service.execute_character_line(line)
	assert_bool(_engine.statement_service.is_paused()).is_true()


func test_character_line_emits_signal() -> void:
	var line: WeavlyModel.CharacterLine = WeavlyModel.CharacterLine.new("Alice", false, ["hi"])
	var executed: Array[WeavlyModel.CharacterLine] = []
	_service.executed_character_line.connect(
		func(l: WeavlyModel.CharacterLine) -> void: executed.append(l)
	)
	_service.execute_character_line(line)
	assert_array(executed).is_equal([WeavlyTextUtils.fill_character_line(line, _engine)])
