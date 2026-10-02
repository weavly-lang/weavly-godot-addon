extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/runtime/services/implementations/default_command_service.gd"
)

var _service: Service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)
	_service.add_declaration(WeavlyModel.Signature.new("play_sound", ["string"] as Array[String]))


func test_execute_command_calls_the_handler_with_the_values() -> void:
	var played: Array[String] = []
	_service.register_command("play_sound", func(sound: String) -> void: played.append(sound))
	var command: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new("play_sound")
	command.values = ["explosion"]
	_service.execute_command(command)
	assert_array(played).is_equal(["explosion"])


func test_unregistered_lists_declared_commands_without_a_handler() -> void:
	assert_array(_service.get_unregistered()).is_equal(["play_sound"])
	_service.register_command("play_sound", func(_sound: String) -> void: pass)
	assert_array(_service.get_unregistered()).is_empty()
