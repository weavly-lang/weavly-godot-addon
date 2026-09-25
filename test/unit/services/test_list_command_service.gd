extends GdUnitTestSuite

const Service = preload("res://addons/weavly/src/services/implementations/list_command_service.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	_service = Service.new()
	_service.initialize(_engine)


# =====================
# execute_command — stop
# =====================


func test_stop_command_holds_the_dialogue() -> void:
	var cmd := WeavlyModel.CommandStatement.new("stop")
	_service.execute_command(cmd)
	assert_int(_engine.holds).is_equal(1)


func test_stop_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("stop")
	monitor_signals(_service, false)
	_service.execute_command(cmd)
	await assert_signal(_service).is_emitted("executed_command", [cmd])


# =====================
# execute_command — other
# =====================


func test_non_stop_command_does_not_hold() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound")
	_service.execute_command(cmd)
	assert_int(_engine.holds).is_equal(0)


func test_non_stop_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound")
	monitor_signals(_service, false)
	_service.execute_command(cmd)
	await assert_signal(_service).is_emitted("executed_command", [cmd])
