@abstract class_name WeavlyCommandService
extends WeavlyService

# command.values holds the evaluated arguments.
signal executed_command(command: WeavlyModel.CommandStatement)

@abstract func execute_command(command: WeavlyModel.CommandStatement) -> void
