extends WeavlyCommandService

const STOP_COMMAND_ID = "stop"


func execute_command(command: WeavlyModel.CommandStatement, args: Array) -> void:
	if command.id == STOP_COMMAND_ID:
		engine.statement_service.pause()
	executed_command.emit(command, args)
