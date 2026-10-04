@abstract class_name WeavlyCommandService
extends WeavlyService

# The engine has checked the callable against the declaration.
@abstract func register_command(name: String, callable: Callable) -> void

# Runs the command with command.values, the evaluated arguments.
@abstract func execute_command(command: WeavlyModel.CommandStatement) -> void

# The declared commands this service can't run; the engine reports them on first use.
@abstract func get_unregistered() -> Array[String]
