class_name WeavlyDefaultCommandService
extends WeavlyCommandService

const KIND = "command"
const MISSING_HANDLER = "Can't run command '%s' because no handler is registered for it."

var _declarations: Dictionary[String, WeavlyModel.Signature] = {}
var _handlers: Dictionary[String, Callable] = {}


func add_declaration(signature: WeavlyModel.Signature) -> void:
	_declarations[signature.name] = signature


func register_command(name: String, callable: Callable) -> void:
	if WeavlyModel.Signature.can_register(KIND, name, callable, _declarations):
		_handlers[name] = callable


func execute_command(command: WeavlyModel.CommandStatement) -> void:
	var handler: Callable = _handlers.get(command.id, Callable())
	if not handler.is_valid():
		engine.report_error(MISSING_HANDLER % command.id)
		return
	handler.callv(command.values)


func get_unregistered() -> Array[String]:
	var names: Array[String] = []
	for name: String in _declarations:
		if not _handlers.has(name):
			names.append(name)
	return names
