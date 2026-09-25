# gdlint:ignore = max-public-methods
@abstract class_name WeavlyEngine
extends Node

signal started_dialogue
signal entered_node(node_id: String)
signal finished_dialogue
signal runtime_error(message: String, source: String, line: int)
signal state_loaded

const DRAW_IN_PROGRESS = "Dialogue is already in progress, can't draw from %s."

var character_service: WeavlyCharacterService
var command_service: WeavlyCommandService
var image_service: WeavlyImageService
var line_service: WeavlyLineService
var node_service: WeavlyNodeService
var option_service: WeavlyOptionService
var statement_service: WeavlyStatementService
var variable_service: WeavlyVariableService
var video_service: WeavlyVideoService

# @random and random() roll with this, so a seed and a saved state reproduce them.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var current_node_id: String = ""
var current_source: String = ""
var current_line: int = 0

var _rendering: bool = false
var _render_output: Array[WeavlyModel.Statement] = []
# The options choose() and render_option() accept, with the source of their node.
var _rendered_options: Dictionary[WeavlyModel.Option, String] = {}

@abstract func start(node_id: String) -> void

@abstract func render(node_id: String) -> Array[WeavlyModel.Statement]

@abstract func render_option(option: WeavlyModel.Option) -> Array[WeavlyModel.Statement]

@abstract func choose(option: WeavlyModel.Option) -> void

@abstract func enter_node(node_id: String) -> void

@abstract func next() -> void

@abstract func finish() -> void

@abstract func is_running() -> bool

@abstract func hold() -> void

@abstract func release() -> void

@abstract func get_state() -> Dictionary

@abstract func set_state(state: Dictionary) -> void

@abstract func reset_state() -> void


func is_rendering() -> bool:
	return _rendering


# While rendering, the executor collects filled lines, commands and option blocks here.
func add_rendered(statement: WeavlyModel.Statement) -> void:
	_render_output.append(statement)
	if statement is WeavlyModel.OptionBlock:
		for option: WeavlyModel.Option in statement.options:
			_rendered_options[option] = current_source


# Storylet node ids from the pools in selection order, each taken while its slots are free.
func list_pool(...pools: Array) -> Array[String]:
	return WeavlyStoryletSelector.list_pool(self, pools)


# What list_pool would return now, without changing skip counts or the generator.
func peek_pool(...pools: Array) -> Array[String]:
	return WeavlyStoryletSelector.peek_pool(self, pools)


# Starts a dialogue with the first node in selection order; false when none is eligible.
func draw(...pools: Array) -> bool:
	if is_running():
		push_warning(DRAW_IN_PROGRESS % ", ".join(PackedStringArray(pools)))
		return false
	var node_id: String = WeavlyStoryletSelector.draw(self, pools)
	if node_id == "":
		return false
	start(node_id)
	return true


func report_error(message: String) -> void:
	push_error(_locate(message))
	runtime_error.emit(message, current_source, current_line)


func set_location(node: WeavlyModel.WeavlyNode) -> void:
	current_source = node.source
	current_line = node.line


func clear_location() -> void:
	current_source = ""
	current_line = 0


func _locate(message: String) -> String:
	if current_source != "" and current_line > 0:
		return "%s:%d: error: %s" % [current_source, current_line, message]
	return message


# Counts a visit to the current node; later calls until the next node is entered do nothing.
func leave_current_node() -> void:
	if current_node_id == "":
		return
	node_service.record_visit(current_node_id)
	current_node_id = ""
