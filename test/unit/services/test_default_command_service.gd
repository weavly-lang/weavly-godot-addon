extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _service: WeavlyDefaultCommandService


func before_test() -> void:
	var engine: FakeEngine = auto_free(FakeEngine.new())
	engine.story.add_command(WeavlyModel.Signature.new("play_sound", ["string"] as Array[String]))
	_service = engine.command_service


func test_execute_command_calls_the_handler_with_the_values() -> void:
	var played: Array[String] = []
	_service.register_command("play_sound", func(sound: String) -> void: played.append(sound))
	var command: WeavlyModel.CommandStatement = WeavlyModel.CommandStatement.new("play_sound")
	command.values = ["explosion"]
	_service.execute_command(command)
	assert_array(played).is_equal(["explosion"])


func test_a_command_without_a_handler_is_reported() -> void:
	_service.execute_command(WeavlyModel.CommandStatement.new("play_sound"))
	assert_logged(["Can't run command 'play_sound' because no handler is registered for it."])


func test_unregistered_lists_declared_commands_without_a_handler() -> void:
	assert_array(_service.get_unregistered()).is_equal(["play_sound"])
	_service.register_command("play_sound", func(_sound: String) -> void: pass)
	assert_array(_service.get_unregistered()).is_empty()
