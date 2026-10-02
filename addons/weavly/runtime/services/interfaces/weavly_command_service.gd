@abstract class_name WeavlyCommandService
extends WeavlyService

@abstract func add_declaration(signature: WeavlyModel.Signature) -> void

@abstract func register_command(name: String, callable: Callable) -> void

# Calls the command's handler with command.values, the evaluated arguments.
@abstract func execute_command(command: WeavlyModel.CommandStatement) -> void

# The declared commands without a registered handler.
@abstract func get_unregistered() -> Array[String]
