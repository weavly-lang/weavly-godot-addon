@abstract class_name WeavlyCommandService
extends WeavlyService

signal executed_command(command: WeavlyModel.CommandStatement)


@abstract func execute_command(_command: WeavlyModel.CommandStatement) -> void
