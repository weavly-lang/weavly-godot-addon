extends GdUnitTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_command_service.gd"
)

var _service: Service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


func test_execute_command_emits_signal() -> void:
	var cmd: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new("play_sound")
	cmd.values = ["explosion"]
	var executed: Array[WeavlyModel.CommandStatement] = []
	_service.executed_command.connect(
		func(c: WeavlyModel.CommandStatement) -> void: executed.append(c)
	)
	_service.execute_command(cmd)
	assert_array(executed).is_equal([cmd])
