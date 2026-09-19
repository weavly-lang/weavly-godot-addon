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


func test_stop_command_pauses_statement_service() -> void:
	var cmd := WeavlyModel.CommandStatement.new("stop", "")
	_service.execute_command(cmd)
	assert_bool(_engine.statement_service.is_paused()).is_true()


func test_stop_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("stop", "")
	monitor_signals(_service, false)
	_service.execute_command(cmd)
	await assert_signal(_service).is_emitted("executed_command", [cmd])


# =====================
# execute_command — other
# =====================


func test_non_stop_command_does_not_pause() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound", "explosion")
	_service.execute_command(cmd)
	assert_bool(_engine.statement_service.is_paused()).is_false()


func test_non_stop_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound", "explosion")
	monitor_signals(_service, false)
	_service.execute_command(cmd)
	await assert_signal(_service).is_emitted("executed_command", [cmd])
