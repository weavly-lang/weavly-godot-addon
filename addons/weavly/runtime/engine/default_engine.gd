class_name WeavlyDefaultEngine
extends WeavlyEngine

const DIALOGUE_IN_PROGRESS = "Dialogue is already in progress, can't start for node with ID '%s'."
const MISSING_NODE = "Can't enter node '%s' because it doesn't exist, finishing the dialogue."
const JUMP_CYCLE = "Entered %d nodes without pausing (likely a jump cycle); finishing the dialogue."
const DETOUR_TOO_DEEP = "Can't detour to node '%s' past %d running nodes; finishing the dialogue."
const NOT_HELD = "release() was called without a matching hold()."
const UNKNOWN_STATE_VERSION = "Can't load a state of version '%s', expected version %d."
const MISSING_SAVED_NODE = "Can't resume at node '%s' because it no longer exists."
const RENDER_IN_PROGRESS = "Dialogue is already in progress, can't render node '%s'."
const CHOOSE_IN_PROGRESS = "Dialogue is already in progress, can't choose option '%s'."
const NOT_RENDERED = "Can't choose option '%s' because it wasn't rendered."
const LOCKED_OPTION = "Can't choose option '%s' because it's locked."

const STATE_VERSION = 2
const KEY_VERSION = "version"
const KEY_NODE = "node"
const KEY_SERVICES = "services"
const KEY_RNG = "rng"
const KEY_RENDERED = "rendered"

const DEFAULTS_PATH = "res://addons/weavly/runtime/services/implementations/"
const DEFAULT_CHARACTER_SERVICE = preload(DEFAULTS_PATH + "default_character_service.gd")
const DEFAULT_COMMAND_SERVICE = preload(DEFAULTS_PATH + "default_command_service.gd")
const DEFAULT_FUNCTION_SERVICE = preload(DEFAULTS_PATH + "default_function_service.gd")
const DEFAULT_IMAGE_SERVICE = preload(DEFAULTS_PATH + "default_image_service.gd")
const DEFAULT_LINE_SERVICE = preload(DEFAULTS_PATH + "default_line_service.gd")
const DEFAULT_NODE_SERVICE = preload(DEFAULTS_PATH + "default_node_service.gd")
const DEFAULT_OPTION_SERVICE = preload(DEFAULTS_PATH + "default_option_service.gd")
const DEFAULT_STATEMENT_SERVICE = preload(DEFAULTS_PATH + "default_statement_service.gd")
const DEFAULT_VARIABLE_SERVICE = preload(DEFAULTS_PATH + "default_variable_service.gd")
const DEFAULT_VIDEO_SERVICE = preload(DEFAULTS_PATH + "default_video_service.gd")

# Slot -> [default script, base type]; each slot has a <slot>_service and <slot>_service_script.
static var _service_types: Dictionary[String, Array] = {
	"character": [DEFAULT_CHARACTER_SERVICE, WeavlyCharacterService],
	"command": [DEFAULT_COMMAND_SERVICE, WeavlyCommandService],
	"function": [DEFAULT_FUNCTION_SERVICE, WeavlyFunctionService],
	"image": [DEFAULT_IMAGE_SERVICE, WeavlyImageService],
	"line": [DEFAULT_LINE_SERVICE, WeavlyLineService],
	"node": [DEFAULT_NODE_SERVICE, WeavlyNodeService],
	"option": [DEFAULT_OPTION_SERVICE, WeavlyOptionService],
	"statement": [DEFAULT_STATEMENT_SERVICE, WeavlyStatementService],
	"variable": [DEFAULT_VARIABLE_SERVICE, WeavlyVariableService],
	"video": [DEFAULT_VIDEO_SERVICE, WeavlyVideoService],
}

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
## How many nodes can run at once through detours, drawn and chosen nodes.
@export var max_detour_depth: int = 64
## 0 picks a new seed on every run.
@export var random_seed: int = 0

@export var character_service_script: Script
@export var command_service_script: Script
@export var function_service_script: Script
@export var image_service_script: Script
@export var line_service_script: Script
@export var node_service_script: Script
@export var option_service_script: Script
@export var statement_service_script: Script
@export var variable_service_script: Script
@export var video_service_script: Script

# Null when no node is waiting to be entered.
var _pending_node_id: Variant = null
var _pending_detour: bool = false
var _in_next: bool = false

var _finished: bool = true

var _holds: int = 0
var _hold_interrupted_step: bool = false

var _checkpoint: Dictionary = {}
# A variable changed during a step or render; offered options refresh once it ends.
var _options_stale: bool = false
var _initial_state: Dictionary = {}


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	for slot: String in _service_types:
		var user_script: Script = get(slot + "_service_script")
		set(
			slot + "_service",
			create_service(self, user_script, _service_types[slot][0], _service_types[slot][1])
		)
	image_service.set_group_pattern(image_group_pattern)
	image_service.set_supported_extensions(image_extensions)
	video_service.set_group_pattern(video_group_pattern)
	video_service.set_supported_extensions(video_extensions)

	variable_service.variable_changed.connect(_on_variable_changed)
	WeavlyFileUtils.load_dialogue(self, dialogue_path, variable_path)
	WeavlyFileUtils.index_media_from_files(video_service, video_path)
	WeavlyFileUtils.index_media_from_files(image_service, image_path)
	WeavlyFileUtils.index_characters_from_resources(self, character_path)
	_initial_state = get_state()
	if random_seed == 0:
		_initial_state.erase(KEY_RNG)


func start(node_id: String) -> void:
	if not _finished:
		push_warning(DIALOGUE_IN_PROGRESS % node_id)
	else:
		_check_registrations()
		_finished = false
		clear_location()
		started_dialogue.emit()
		enter_node(node_id)


# Runs the whole node without pausing and returns filled copies of its lines, commands and
# option blocks. State changes, visits and entered_node happen as in normal play.
func render(node_id: String) -> Array[WeavlyModel.Statement]:
	if not _finished:
		push_warning(RENDER_IN_PROGRESS % node_id)
		return []
	_check_registrations()
	_begin_render()
	enter_node(node_id)
	return _end_render()


# Runs a chosen option like render(), following jumps into other nodes.
func render_option(option: WeavlyModel.Option) -> Array[WeavlyModel.Statement]:
	if not _accept_choice(option):
		return []
	_begin_render()
	_run_choice(option)
	return _end_render()


# Starts a dialogue with a rendered option or one from get_option. An inline option runs only
# its action, since the rest of its node already ran; a node option runs its node.
func choose(option: WeavlyModel.Option) -> void:
	if not _accept_choice(option):
		return
	_finished = false
	started_dialogue.emit()
	_run_choice(option)


# Checks the option again; a locked one is refused.
func _accept_choice(option: WeavlyModel.Option) -> bool:
	if not _finished:
		push_warning(CHOOSE_IN_PROGRESS % option.text)
		return false
	if option.item != null and not _rendered_options.has(option):
		push_warning(NOT_RENDERED % option.text)
		return false
	WeavlyOptionBuilder.refresh(option, self)
	if not option.is_choosable():
		push_warning(LOCKED_OPTION % option.text)
		return false
	_rendered_options.clear()
	return true


func _run_choice(option: WeavlyModel.Option) -> void:
	if option.item == null:
		snapshot_meta(option.node_id)
		enter_node(option.node_id)
		return
	current_source = option.source
	current_line = option.line
	statement_service.clear_statements()
	statement_service.add_statements(option.item.body)
	next()


func _begin_render() -> void:
	_rendering = true
	_render_output = []
	_finished = false
	clear_location()


# A render keeps the checkpoint of the last node it entered, marked so loading doesn't start it.
func _end_render() -> Array[WeavlyModel.Statement]:
	var output: Array[WeavlyModel.Statement] = _render_output
	_rendering = false
	_render_output = []
	_finished = true
	_pending_node_id = null
	_location_stack.clear()
	_meta_snapshots.clear()
	clear_location()
	statement_service.clear_statements()
	if not _checkpoint.is_empty():
		_checkpoint[KEY_RENDERED] = true
	_refresh_stale_options()
	return output


func enter_node(node_id: String) -> void:
	_pending_node_id = node_id
	_pending_detour = false
	if not _in_next:
		next()


func detour(node_id: String) -> void:
	_pending_node_id = node_id
	_pending_detour = true
	if not _in_next:
		next()


func next() -> void:
	if _holds > 0:
		return
	_in_next = true
	if (
		option_service.has_options()
		and not option_service.get_options().any(
			func(option: WeavlyModel.Option) -> bool: return option.is_choosable()
		)
	):
		option_service.clear_options()
	statement_service.resume()
	var node_entries: int = 0
	while not statement_service.is_paused() and not option_service.has_options() and not _finished:
		if _pending_node_id != null:
			node_entries += 1
			if node_entries > max_node_entries_per_step:
				report_error(JUMP_CYCLE % max_node_entries_per_step)
				finish()
				break
			_enter_pending_node()
		else:
			statement_service.advance_statements()
	_in_next = false
	_refresh_stale_options()


func _on_variable_changed(_id: String, _value: Variant, _old_value: Variant) -> void:
	if _in_next or _rendering:
		_options_stale = true
	else:
		refresh_options()


func _refresh_stale_options() -> void:
	if _options_stale:
		_options_stale = false
		refresh_options()


func _enter_pending_node() -> void:
	var node_id: String = _pending_node_id
	var detoured: bool = _pending_detour
	_pending_node_id = null
	_pending_detour = false
	if not node_service.has(node_id):
		report_error(MISSING_NODE % node_id)
		finish()
		return
	var node: WeavlyModel.WeavlyNode = node_service.get_node(node_id)
	if not detoured:
		_location_stack.clear()
		statement_service.clear_statements()
		_checkpoint = {
			KEY_VERSION: STATE_VERSION,
			KEY_NODE: node_id,
			KEY_SERVICES: _collect_service_states(),
			KEY_RNG: str(rng.state),
		}
	elif _location_stack.size() >= max_detour_depth:
		report_error(DETOUR_TOO_DEEP % [node_id, max_detour_depth])
		finish()
		return
	_location_stack.push_back(node_id)
	set_location(node)
	statement_service.add_node_statements(node.body)
	entered_node.emit(node_id)


func finish() -> void:
	if _finished:
		return
	leave_all_nodes()
	# A left_node handler may have finished the dialogue already.
	if _finished:
		return
	if _rendering:
		_finished = true
		return
	_stop()
	finished_dialogue.emit()


func _stop() -> void:
	_finished = true
	_holds = 0
	_hold_interrupted_step = false
	_pending_node_id = null
	_pending_detour = false
	_checkpoint = {}
	_location_stack.clear()
	_meta_snapshots.clear()
	clear_location()
	statement_service.clear_statements()
	option_service.clear_options()


func is_running() -> bool:
	return not _finished


# While a dialogue runs, the state as its current node was entered, so loading replays that node.
# After a render, the state as its last node was entered, marked as rendered.
func get_state() -> Dictionary:
	if not _checkpoint.is_empty():
		return _checkpoint.duplicate(true)
	return {
		KEY_VERSION: STATE_VERSION,
		KEY_SERVICES: _collect_service_states(),
		KEY_RNG: str(rng.state),
	}


func set_state(state: Dictionary) -> void:
	if state.get(KEY_VERSION) != STATE_VERSION:
		push_error(UNKNOWN_STATE_VERSION % [state.get(KEY_VERSION), STATE_VERSION])
		return
	_stop()
	_rendered_options.clear()
	var saved: Variant = state.get(KEY_SERVICES, {})
	var service_states: Dictionary = saved if saved is Dictionary else {}
	var services: Dictionary = _services()
	for slot: String in services:
		var service_state: Variant = service_states.get(slot, {})
		services[slot].set_state(service_state if service_state is Dictionary else {})
	var rng_state: Variant = state.get(KEY_RNG)
	if rng_state is String:
		rng.state = rng_state.to_int()
	state_loaded.emit()

	var node_id: Variant = state.get(KEY_NODE)
	if node_id is not String or state.get(KEY_RENDERED) == true:
		return
	if not node_service.has(node_id):
		push_error(MISSING_SAVED_NODE % node_id)
		return
	start(node_id)


func reset_state() -> void:
	set_state(_initial_state.duplicate(true))


func _services() -> Dictionary:
	var services: Dictionary = {}
	for slot: String in _service_types:
		services[slot] = get(slot + "_service")
	return services


func _collect_service_states() -> Dictionary:
	var states: Dictionary = {}
	var services: Dictionary = _services()
	for slot: String in services:
		var state: Dictionary = services[slot].get_state()
		if not state.is_empty():
			states[slot] = state
	return states


func hold() -> void:
	if _holds == 0:
		_hold_interrupted_step = _in_next
	_holds += 1
	statement_service.pause()


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


# Falls back to the default script when the user's doesn't extend the base type.
static func create_service(
	engine: WeavlyEngine, user_script: Script, default_script: Script, base_type: Variant
) -> WeavlyService:
	var script_to_use: Script = user_script if user_script != null else default_script
	var instance: WeavlyService = script_to_use.new()
	if is_instance_of(instance, base_type):
		instance.initialize(engine)
		return instance

	push_warning("%s must extend %s. Falling back to default." % [script_to_use, base_type])
	var default_instance: WeavlyService = default_script.new()
	default_instance.initialize(engine)
	return default_instance
