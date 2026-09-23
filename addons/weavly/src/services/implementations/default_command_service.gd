extends WeavlyCommandService


func execute_command(command: WeavlyModel.CommandStatement, args: Array) -> void:
	executed_command.emit(command, args)
