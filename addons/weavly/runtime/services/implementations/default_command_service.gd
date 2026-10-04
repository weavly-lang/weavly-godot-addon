class_name WeavlyDefaultCommandService
extends WeavlyCommandService

const MISSING_HANDLER = "Can't run command '%s' because no handler is registered for it."

var _handlers: Dictionary[String, Callable] = {}


func register_command(name: String, callable: Callable) -> void:
	_handlers[name] = callable


func execute_command(command: WeavlyModel.CommandStatement) -> void:
	var handler: Callable = _handlers.get(command.id, Callable())
	if not handler.is_valid():
		engine.report_error(MISSING_HANDLER % command.id)
		return
	handler.callv(command.values)


func get_unregistered() -> Array[String]:
	var names: Array[String] = []
	for name: String in engine.story.get_command_names():
		if not _handlers.has(name):
			names.append(name)
	return names
