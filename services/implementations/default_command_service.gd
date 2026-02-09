extends WeavlyCommandService

func execute_command(command: WeavlyModel.CommandStatement) -> void:
	executed_command.emit(command)
