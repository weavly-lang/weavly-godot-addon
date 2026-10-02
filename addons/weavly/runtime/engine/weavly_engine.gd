# gdlint:ignore = max-public-methods
@abstract class_name WeavlyEngine
extends Node

signal started_dialogue
signal entered_node(node_id: String)
signal left_node(node_id: String)
signal finished_dialogue
signal runtime_error(message: String, source: String, line: int)
signal state_loaded

# How a pool treats nodes shown locked: SHOW counts them toward the limit, EXTRA shows them
# on top of it, HIDE leaves them out.
enum Locked { SHOW, EXTRA, HIDE }

const DRAW_IN_PROGRESS = "Dialogue is already in progress, can't draw from %s."
const UNREGISTERED_FUNCTION = "Function '%s' is declared, but no callable is registered for it."
const UNREGISTERED_COMMAND = "Command '%s' is declared, but no handler is registered for it."

var character_service: WeavlyCharacterService
var command_service: WeavlyCommandService
var function_service: WeavlyFunctionService
var image_service: WeavlyImageService
var line_service: WeavlyLineService
var node_service: WeavlyNodeService
var option_service: WeavlyOptionService
var statement_service: WeavlyStatementService
var variable_service: WeavlyVariableService
var video_service: WeavlyVideoService

# @random and random() roll with this, so a seed and a saved state reproduce them.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# The top of the location stack.
var current_node_id: String:
	get:
		return "" if _location_stack.is_empty() else _location_stack.back()
var current_source: String = ""
var current_line: int = 0

# The running nodes, bottom to top: each detour pushes, each node that ends pops.
var _location_stack: Array[String] = []
var _rendering: bool = false
var _render_output: Array[WeavlyModel.Statement] = []
# The inline options choose() and render_option() accept.
var _rendered_options: Dictionary[WeavlyModel.Option, bool] = {}
# get_option's results, refreshed while the game holds them.
var _listed_options: Array[WeakRef] = []
var _registrations_checked: bool = false
# Node id -> meta values taken when it was chosen; meta reads use them while it runs.
var _meta_snapshots: Dictionary[String, Dictionary] = {}

@abstract func start(node_id: String) -> void

@abstract func render(node_id: String) -> Array[WeavlyModel.Statement]

@abstract func render_option(option: WeavlyModel.Option) -> Array[WeavlyModel.Statement]

@abstract func choose(option: WeavlyModel.Option) -> void

@abstract func enter_node(node_id: String) -> void

@abstract func detour(node_id: String) -> void

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
			_rendered_options[option] = true


# The callable gets the arguments in declaration order, and must not change state:
# conditions are evaluated often and in no fixed order.
func register_function(name: String, callable: Callable) -> void:
	function_service.register_function(name, callable)


# The handler gets the arguments in declaration order; to wait, it calls hold() and release().
func register_command(name: String, callable: Callable) -> void:
	command_service.register_command(name, callable)


# Runs a rendered command through its handler.
func run_command(command: WeavlyModel.CommandStatement) -> void:
	command_service.execute_command(command)


# Up to limit storylet ids in selection order, each taken while its slots are free; -1 takes all.
# Without shuffle, nodes of one priority keep their source order and weight isn't read.
func list_pool(
	pools: Array, limit: int = -1, shuffle: bool = true, locked: Locked = Locked.SHOW
) -> Array[String]:
	_check_registrations()
	return WeavlyStoryletSelector.list_pool(self, pools, limit, shuffle, locked)


# What list_pool would return now, without changing skip counts or the generator.
func peek_pool(
	pools: Array, limit: int = -1, shuffle: bool = true, locked: Locked = Locked.SHOW
) -> Array[String]:
	_check_registrations()
	return WeavlyStoryletSelector.peek_pool(self, pools, limit, shuffle, locked)


# The node as a block would offer it, or null when the display rule hides it. It stays live
# like an offered option, and choose() accepts it.
func get_option(node_id: String) -> WeavlyModel.Option:
	_check_registrations()
	var rng_state: int = rng.state
	var option: WeavlyModel.Option = WeavlyOptionBuilder.offer_node(self, node_id)
	rng.state = rng_state
	if option != null:
		_listed_options = _listed_options.filter(
			func(held: WeakRef) -> bool: return held.get_ref() != null
		)
		_listed_options.append(weakref(option))
	return option


# Evaluates every offered option again, pending, rendered or from get_option; the engine's
# own variable changes do this on their own. The selection and its order stay as offered.
func refresh_options() -> void:
	var options: Array[WeavlyModel.Option] = _offered_options()
	if options.is_empty():
		return
	var rng_state: int = rng.state
	for option: WeavlyModel.Option in options:
		WeavlyOptionBuilder.refresh(option, self)
	rng.state = rng_state
	option_service.options_refreshed.emit()


func _offered_options() -> Array[WeavlyModel.Option]:
	var options: Array[WeavlyModel.Option] = option_service.get_options()
	options.append_array(_rendered_options.keys())
	for held: WeakRef in _listed_options:
		var option: WeavlyModel.Option = held.get_ref()
		if option != null:
			options.append(option)
	return options


# The node's value for a meta key, else the key's default; null once an error is reported.
# Leaves the generator as it was, like peek_pool.
func get_node_meta(node_id: String, key: String) -> Variant:
	_check_registrations()
	var rng_state: int = rng.state
	var value: Variant = WeavlyMetaReader.read(self, node_id, key)
	rng.state = rng_state
	return null if WeavlyExpressionEvaluator.is_error(value) else value


# Starts a dialogue with the first node in selection order; false when none is eligible.
func draw(pools: Array) -> bool:
	if is_running():
		push_warning(DRAW_IN_PROGRESS % ", ".join(PackedStringArray(pools)))
		return false
	_check_registrations()
	var node_id: String = WeavlyStoryletSelector.draw(self, pools)
	if node_id == "":
		return false
	start(node_id)
	return true


# Once, on the game's first use: the game registers after the engine's _ready.
func _check_registrations() -> void:
	if _registrations_checked:
		return
	_registrations_checked = true
	for name: String in function_service.get_unregistered():
		report_error(UNREGISTERED_FUNCTION % name)
	for name: String in command_service.get_unregistered():
		report_error(UNREGISTERED_COMMAND % name)


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


func get_meta_snapshot(node_id: String) -> Dictionary:
	return _meta_snapshots.get(node_id, {})


# Freezes the chosen node's meta values for as long as it runs.
func snapshot_meta(node_id: String) -> void:
	_meta_snapshots[node_id] = WeavlyMetaReader.snapshot(self, node_service.get_node(node_id))


func get_location_stack() -> Array[String]:
	return _location_stack.duplicate()


# Counts a visit to the current node and returns to the node below it.
func leave_current_node() -> void:
	if _location_stack.is_empty():
		return
	var node_id: String = _location_stack.pop_back()
	_meta_snapshots.erase(node_id)
	node_service.record_visit(node_id)
	if not _location_stack.is_empty():
		set_location(node_service.get_node(current_node_id))
	left_node.emit(node_id)


func leave_all_nodes() -> void:
	while not _location_stack.is_empty():
		leave_current_node()
