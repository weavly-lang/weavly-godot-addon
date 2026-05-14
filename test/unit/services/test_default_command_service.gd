extends GutTest

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_command_service.gd"
)

var _service


func before_each() -> void:
	_service = Service.new()
	_service.initialize(null)


func test_execute_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound", "explosion")
	watch_signals(_service)
	_service.execute_command(cmd)
	assert_signal_emitted_with_parameters(_service, "executed_command", [cmd])
