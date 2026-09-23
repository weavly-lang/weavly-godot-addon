@abstract class_name WeavlyEngine
extends Node

signal started_dialogue
signal entered_node(node_id: StringName)
signal finished_dialogue
signal runtime_error(message: String, source: String, line: int)
signal state_loaded

var character_service: WeavlyCharacterService
var command_service: WeavlyCommandService
var image_service: WeavlyImageService
var line_service: WeavlyLineService
var node_service: WeavlyNodeService
var option_service: WeavlyOptionService
var statement_service: WeavlyStatementService
var variable_service: WeavlyVariableService
var video_service: WeavlyVideoService

var current_node_id: String = ""
var current_source: String = ""
var current_line: int = 0

var _location_node_id: String = ""

@abstract func start(node_id: String) -> void

@abstract func enter_node(node_id: String) -> void

@abstract func next() -> void

@abstract func finish() -> void

@abstract func is_running() -> bool

@abstract func hold() -> void

@abstract func release() -> void

@abstract func get_state() -> Dictionary

@abstract func set_state(state: Dictionary) -> void

@abstract func reset_state() -> void


func report_error(message: String) -> void:
	push_error(_locate(message, "error"))
	runtime_error.emit(message, current_source, current_line)


func report_warning(message: String) -> void:
	push_warning(_locate(message, "warning"))


func set_location(node: WeavlyModel.WeavlyNode) -> void:
	current_source = node.source
	current_line = node.line
	_location_node_id = node.id


func clear_location() -> void:
	current_source = ""
	current_line = 0
	_location_node_id = ""


func _locate(message: String, severity: String) -> String:
	if current_source != "" and current_line > 0:
		return "%s:%d: %s: %s" % [current_source, current_line, severity, message]
	if _location_node_id != "":
		var file: String = current_source + ", " if current_source != "" else ""
		return "%snode '%s': %s: %s" % [file, _location_node_id, severity, message]
	return message


# Counts a visit to the current node; later calls until the next node is entered do nothing.
func leave_current_node() -> void:
	if current_node_id == "":
		return
	node_service.record_visit(current_node_id)
	current_node_id = ""
