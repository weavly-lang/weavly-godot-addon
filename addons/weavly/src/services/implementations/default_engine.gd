extends WeavlyEngine

const DIALOG_IN_PROGRESS = "Dialog is already in progress, cant start for node with ID '%s."
const NULL_NODE = "Can't enter node with ID '%s' because it's null, finsishing the dialog."

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

@export var dialog_path: String = "dialog/build"
@export var video_path: String = "media/videos"
@export var image_path: String = "media/images"
@export var character_path: String = "characters"
@export var variable_path: String = "variables"

@export var character_service_script: Script
@export var command_service_script: Script
@export var image_service_script: Script
@export var line_service_script: Script
@export var node_service_script: Script
@export var option_service_script: Script
@export var statement_service_script: Script
@export var variable_service_script: Script
@export var video_service_script: Script

@onready var _finished: bool = true


func _ready() -> void:
	character_service = WeavlyFileUtils.create_service(
		self, 
		character_service_script, 
		DEFAULT_CHARACTER_SERVICE, 
		WeavlyCharacterService
	)
	command_service = WeavlyFileUtils.create_service(
		self, 
		command_service_script, 
		DEFAULT_COMMAND_SERVICE, 
		WeavlyCommandService
	)
	image_service = WeavlyFileUtils.create_service(
		self, 
		image_service_script, 
		DEFAULT_IMAGE_SERVICE, 
		WeavlyImageService
	)
	line_service = WeavlyFileUtils.create_service(
		self, 
		line_service_script, 
		DEFAULT_LINE_SERVICE, 
		WeavlyLineService
	)
	node_service = WeavlyFileUtils.create_service(
		self, 
		node_service_script, 
		DEFAULT_NODE_SERVICE, 
		WeavlyNodeService
	)
	option_service = WeavlyFileUtils.create_service(
		self, 
		option_service_script, 
		DEFAULT_OPTION_SERVICE, 
		WeavlyOptionService
	)
	statement_service = WeavlyFileUtils.create_service(
		self, 
		statement_service_script, 
		DEFAULT_STATEMENT_SERVICE, 
		WeavlyStatementService
	)
	variable_service = WeavlyFileUtils.create_service(
		self, 
		variable_service_script,
		DEFAULT_VARIABLE_SERVICE,
		WeavlyVariableService
	)
	video_service = WeavlyFileUtils.create_service(
		self, 
		video_service_script, 
		DEFAULT_VIDEO_SERVICE, 
		WeavlyVideoService
	)
	
	WeavlyFileUtils.load_nodes_from_files(self, dialog_path)
	WeavlyFileUtils.load_variables_from_resources(self, variable_path)
	WeavlyFileUtils.load_variables_from_env_files(self, dialog_path)
	WeavlyFileUtils.index_videos_from_files(self, video_path)
	WeavlyFileUtils.index_images_from_files(self, image_path)
	WeavlyFileUtils.index_characters_from_resources(self, character_path)
	WeavlyFileUtils.create_visited_flags_from_nodes(self, node_service.get_all_nodes())


func start(node_id: String) -> void:
	if not _finished:
		push_warning(DIALOG_IN_PROGRESS % node_id) 
	else:
		_finished = false
		started_dialog.emit()
		enter_node(node_id)


func enter_node(node_id: String) -> void:
	var node: WeavlyModel.WeavlyNode = node_service.get_node(node_id, null)
	if node != null:
		variable_service.set_variable(node_id, true)
		statement_service.clear_statements()
		statement_service.add_statements(node.body)
		entered_node.emit(node_id)
		next()
	else:
		push_error(NULL_NODE % node_id)
		finish()


func next() -> void:
	statement_service.resume()
	while (
		not statement_service.is_paused()
		and not option_service.has_options() 
		and not _finished
	):
		statement_service.advance_statements()


func finish() -> void:
	finished_dialog.emit()
	_finished = true
	statement_service.clear_statements()
	
