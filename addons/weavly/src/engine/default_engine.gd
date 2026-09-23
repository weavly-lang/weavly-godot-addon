class_name WeavlyDefaultEngine
extends WeavlyEngine

const DIALOGUE_IN_PROGRESS = "Dialogue is already in progress, can't start for node with ID '%s'."
const MISSING_NODE = "Can't enter node '%s' because it doesn't exist, finishing the dialogue."
const GOTO_CYCLE = "Entered %d nodes without pausing (likely a goto cycle); finishing the dialogue."
const NOT_HELD = "release() was called without a matching hold()."
const UNKNOWN_STATE_VERSION = "Can't load a state of version '%s', expected version %d."
const MISSING_SAVED_NODE = "Can't resume at node '%s' because it no longer exists."

const STATE_VERSION = 1
const KEY_VERSION = "version"
const KEY_NODE = "node"
const KEY_SERVICES = "services"

const DEFAULTS_PATH = "res://addons/weavly/src/services/implementations/"
const DEFAULT_CHARACTER_SERVICE = preload(DEFAULTS_PATH + "default_character_service.gd")
const DEFAULT_COMMAND_SERVICE = preload(DEFAULTS_PATH + "default_command_service.gd")
const DEFAULT_IMAGE_SERVICE = preload(DEFAULTS_PATH + "default_image_service.gd")
const DEFAULT_LINE_SERVICE = preload(DEFAULTS_PATH + "default_line_service.gd")
const DEFAULT_NODE_SERVICE = preload(DEFAULTS_PATH + "default_node_service.gd")
const DEFAULT_OPTION_SERVICE = preload(DEFAULTS_PATH + "default_option_service.gd")
const DEFAULT_STATEMENT_SERVICE = preload(DEFAULTS_PATH + "default_statement_service.gd")
const DEFAULT_VARIABLE_SERVICE = preload(DEFAULTS_PATH + "default_variable_service.gd")
const DEFAULT_VIDEO_SERVICE = preload(DEFAULTS_PATH + "default_video_service.gd")

@export var dialogue_path: String = "res://dialogue/build"
@export var video_path: String = "res://media/videos"
@export var image_path: String = "res://media/images"
@export var character_path: String = "res://characters"
@export var variable_path: String = "res://variables"
@export var image_group_pattern: String = ""
@export var video_group_pattern: String = ""
@export var image_extensions: PackedStringArray = [".png", ".jpg"]
@export var video_extensions: PackedStringArray = [".ogv"]
@export var max_node_entries_per_step: int = 10000

@export var character_service_script: Script
@export var command_service_script: Script
@export var image_service_script: Script
@export var line_service_script: Script
@export var node_service_script: Script
@export var option_service_script: Script
@export var statement_service_script: Script
@export var variable_service_script: Script
@export var video_service_script: Script

var _pending_node_id: String = ""
var _has_pending_node: bool = false
var _in_next: bool = false

var _finished: bool = true

var _holds: int = 0
var _hold_interrupted_step: bool = false

var _checkpoint: Dictionary = {}
var _initial_state: Dictionary = {}


func _ready() -> void:
	character_service = WeavlyFileUtils.create_service(
		self, character_service_script, DEFAULT_CHARACTER_SERVICE, WeavlyCharacterService
	)
	command_service = WeavlyFileUtils.create_service(
		self, command_service_script, DEFAULT_COMMAND_SERVICE, WeavlyCommandService
	)
	image_service = WeavlyFileUtils.create_service(
		self, image_service_script, DEFAULT_IMAGE_SERVICE, WeavlyImageService
	)
	image_service.set_group_pattern(image_group_pattern)
	image_service.set_supported_extensions(image_extensions)
	line_service = WeavlyFileUtils.create_service(
		self, line_service_script, DEFAULT_LINE_SERVICE, WeavlyLineService
	)
	node_service = WeavlyFileUtils.create_service(
		self, node_service_script, DEFAULT_NODE_SERVICE, WeavlyNodeService
	)
	option_service = WeavlyFileUtils.create_service(
		self, option_service_script, DEFAULT_OPTION_SERVICE, WeavlyOptionService
	)
	statement_service = WeavlyFileUtils.create_service(
		self, statement_service_script, DEFAULT_STATEMENT_SERVICE, WeavlyStatementService
	)
	variable_service = WeavlyFileUtils.create_service(
		self, variable_service_script, DEFAULT_VARIABLE_SERVICE, WeavlyVariableService
	)
	video_service = WeavlyFileUtils.create_service(
		self, video_service_script, DEFAULT_VIDEO_SERVICE, WeavlyVideoService
	)
	video_service.set_group_pattern(video_group_pattern)
	video_service.set_supported_extensions(video_extensions)

	WeavlyFileUtils.load_nodes_from_files(self, dialogue_path)
	WeavlyFileUtils.load_variables(self, dialogue_path, variable_path)
	WeavlyFileUtils.index_videos_from_files(self, video_path)
	WeavlyFileUtils.index_images_from_files(self, image_path)
	WeavlyFileUtils.index_characters_from_resources(self, character_path)
	_initial_state = get_state()


func start(node_id: String) -> void:
	if not _finished:
		push_warning(DIALOGUE_IN_PROGRESS % node_id)
	else:
		_finished = false
		clear_location()
		started_dialogue.emit()
		enter_node(node_id)


func enter_node(node_id: String) -> void:
	_pending_node_id = node_id
	_has_pending_node = true
	if not _in_next:
		next()


func next() -> void:
	if _holds > 0:
		return
	_in_next = true
	statement_service.resume()
	var node_entries: int = 0
	while not statement_service.is_paused() and not option_service.has_options() and not _finished:
		if _has_pending_node:
			node_entries += 1
			if node_entries > max_node_entries_per_step:
				report_error(GOTO_CYCLE % max_node_entries_per_step)
				finish()
				break
			_enter_pending_node()
		else:
			statement_service.advance_statements()
	_in_next = false


func _enter_pending_node() -> void:
	var node_id: String = _pending_node_id
	_has_pending_node = false
	_pending_node_id = ""
	if not node_service.has(node_id):
		report_error(MISSING_NODE % node_id)
		finish()
		return
	var node: WeavlyModel.WeavlyNode = node_service.get_node(node_id)
	_checkpoint = {
		KEY_VERSION: STATE_VERSION,
		KEY_NODE: node_id,
		KEY_SERVICES: _collect_service_states(),
	}
	current_node_id = node_id
	set_location(node)
	statement_service.clear_statements()
	statement_service.add_statements(node.body)
	entered_node.emit(node_id)


func finish() -> void:
	if _finished:
		return
	_stop()
	finished_dialogue.emit()


func _stop() -> void:
	_finished = true
	_holds = 0
	_hold_interrupted_step = false
	_has_pending_node = false
	_pending_node_id = ""
	_checkpoint = {}
	current_node_id = ""
	clear_location()
	statement_service.clear_statements()
	option_service.clear_options()


func is_running() -> bool:
	return not _finished


func hold() -> void:
	if _holds == 0:
		_hold_interrupted_step = _in_next
	_holds += 1
	statement_service.pause()


# While a dialogue runs, the state as its current node was entered, so loading replays that node.
func get_state() -> Dictionary:
	if not _finished and not _checkpoint.is_empty():
		return _checkpoint.duplicate(true)
	return {KEY_VERSION: STATE_VERSION, KEY_SERVICES: _collect_service_states()}


func set_state(state: Dictionary) -> void:
	if state.get(KEY_VERSION) != STATE_VERSION:
		push_error(UNKNOWN_STATE_VERSION % [state.get(KEY_VERSION), STATE_VERSION])
		return
	_stop()
	var saved: Variant = state.get(KEY_SERVICES, {})
	var service_states: Dictionary = saved if saved is Dictionary else {}
	var services: Dictionary = _services()
	for slot: String in services:
		var service_state: Variant = service_states.get(slot, {})
		services[slot].set_state(service_state if service_state is Dictionary else {})
	state_loaded.emit()

	var node_id: Variant = state.get(KEY_NODE)
	if node_id is not String:
		return
	if not node_service.has(node_id):
		push_error(MISSING_SAVED_NODE % node_id)
		return
	start(node_id)


func reset_state() -> void:
	set_state(_initial_state.duplicate(true))


func _services() -> Dictionary:
	return {
		"character": character_service,
		"command": command_service,
		"image": image_service,
		"line": line_service,
		"node": node_service,
		"option": option_service,
		"statement": statement_service,
		"variable": variable_service,
		"video": video_service,
	}


func _collect_service_states() -> Dictionary:
	var states: Dictionary = {}
	var services: Dictionary = _services()
	for slot: String in services:
		var state: Dictionary = services[slot].get_state()
		if not state.is_empty():
			states[slot] = state
	return states


# The last release continues only a step the hold interrupted; a line on screen keeps waiting.
func release() -> void:
	if _holds == 0:
		push_warning(NOT_HELD)
		return
	_holds -= 1
	if _holds > 0 or not _hold_interrupted_step:
		return
	_hold_interrupted_step = false
	if _in_next:
		statement_service.resume()
	else:
		next()
