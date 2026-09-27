class_name WeavlyTestSuite
extends GdUnitTestSuite


# Declares a variable typed after its value, as @env would.
func declare_variable(engine: WeavlyEngine, id: String, value: Variant) -> void:
	var variable: WeavlyModel.Variable
	if value is float:
		variable = WeavlyModel.NumberVariable.new(id, value, null, null)
	elif value is String:
		variable = WeavlyModel.StringVariable.new(id, value)
	else:
		variable = WeavlyModel.FlagVariable.new(id, value)
	engine.variable_service.add_variable(variable)


func mouse_button(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func action_pressed(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


# Whether handler marks event as handled in viewport, so it doesn't reach the game.
func handles_input(handler: Callable, event: InputEvent, viewport: Viewport = null) -> bool:
	if viewport == null:
		viewport = get_viewport()
	viewport.push_input(InputEventAction.new())
	handler.call(event)
	return viewport.is_input_handled()


# gdUnit4's assert_error() can only assert one error per call; this consumes several.
func assert_logged(errors: Array[String], warnings: Array[String] = []) -> void:
	var monitor: GodotGdErrorMonitor = (
		GdUnitThreadManager.get_current_context().get_execution_context().error_monitor
	)
	_consume_logged(monitor, ErrorLogEntry.TYPE.PUSH_ERROR, errors)
	_consume_logged(monitor, ErrorLogEntry.TYPE.PUSH_WARNING, warnings)


func _consume_logged(
	monitor: GodotGdErrorMonitor, type: ErrorLogEntry.TYPE, expected: Array[String]
) -> void:
	for message: String in expected:
		var found: ErrorLogEntry = null
		for entry: ErrorLogEntry in monitor.log_entries():
			if entry._type == type and entry._message.contains(message):
				found = entry
				break
		if found == null:
			fail(
				(
					"Expected a logged %s containing '%s', got: %s"
					% [ErrorLogEntry.TYPE.keys()[type], message, monitor.log_entries()]
				)
			)
			return
		monitor.log_entries().erase(found)
