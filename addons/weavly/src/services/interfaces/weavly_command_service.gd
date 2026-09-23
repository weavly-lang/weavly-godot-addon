@abstract class_name WeavlyCommandService
extends WeavlyService

signal executed_command(command: WeavlyModel.CommandStatement, args: Array)

@abstract func execute_command(command: WeavlyModel.CommandStatement, args: Array) -> void
