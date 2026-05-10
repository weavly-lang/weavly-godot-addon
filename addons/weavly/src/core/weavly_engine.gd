extends Node
class_name WeavlyEngine

signal started_dialog
signal entered_node(node_id: StringName)
signal finished_dialog

var character_service: WeavlyCharacterService
var command_service: WeavlyCommandService
var image_service: WeavlyImageService
var line_service: WeavlyLineService
var node_service: WeavlyNodeService
var option_service: WeavlyOptionService
var statement_service: WeavlyStatementService
var variable_service: WeavlyVariableService
var video_service: WeavlyVideoService


func start(node_id: String) -> void:
	pass


func enter_node(node_id: String) -> void:
	pass


func next() -> void:
	pass


func finish() -> void:
	pass
