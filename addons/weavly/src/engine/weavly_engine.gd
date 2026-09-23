@abstract class_name WeavlyEngine
extends Node

signal started_dialogue
signal entered_node(node_id: StringName)
signal finished_dialogue

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

@abstract func start(node_id: String) -> void

@abstract func enter_node(node_id: String) -> void

@abstract func next() -> void

@abstract func finish() -> void

@abstract func is_running() -> bool


# Counts a visit to the current node; later calls until the next node is entered do nothing.
func leave_current_node() -> void:
	if current_node_id == "":
		return
	node_service.record_visit(current_node_id)
	current_node_id = ""
