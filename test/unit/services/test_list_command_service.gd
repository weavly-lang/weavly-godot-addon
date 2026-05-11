extends GutTest

const Service = preload("res://addons/weavly/src/services/implementations/list_command_service.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func before_each() -> void:
	_engine = add_child_autofree(FakeEngine.new())
	_service = Service.new()
	_service.initialize(_engine)


# =====================
# execute_command — stop
# =====================


func test_stop_command_pauses_statement_service() -> void:
	var cmd := WeavlyModel.CommandStatement.new("stop", "")
	_service.execute_command(cmd)
	assert_true(_engine.statement_service.is_paused())


func test_stop_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("stop", "")
	watch_signals(_service)
	_service.execute_command(cmd)
	assert_signal_emitted_with_parameters(_service, "executed_command", [cmd])


# =====================
# execute_command — other
# =====================


func test_non_stop_command_does_not_pause() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound", "explosion")
	_service.execute_command(cmd)
	assert_false(_engine.statement_service.is_paused())


func test_non_stop_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound", "explosion")
	watch_signals(_service)
	_service.execute_command(cmd)
	assert_signal_emitted_with_parameters(_service, "executed_command", [cmd])
