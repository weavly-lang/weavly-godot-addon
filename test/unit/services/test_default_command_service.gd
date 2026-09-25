extends GdUnitTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_command_service.gd"
)

var _service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


func test_execute_command_emits_signal() -> void:
	var cmd := WeavlyModel.CommandStatement.new("play_sound")
	cmd.values = ["explosion"]
	monitor_signals(_service, false)
	_service.execute_command(cmd)
	await assert_signal(_service).is_emitted("executed_command", [cmd])
