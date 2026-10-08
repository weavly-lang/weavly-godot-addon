# gdlint:ignore = max-public-methods
class_name WeavlyEngine
extends Node

signal started_dialogue
signal entered_node(node_id: String)
signal left_node(node_id: String)
signal finished_dialogue
signal runtime_error(message: String, source: String, line: int)
signal state_loaded
# A statement is about to run, in play and in renders; hold() pauses the dialogue after it.
signal statement_reached(statement: WeavlyModel.Statement)
# A line in play, its text filled in; it waits for next() unless the line service says not to.
signal line_reached(line: WeavlyModel.LineStatement)
signal options_offered(options: Array[WeavlyModel.Option])
signal option_chosen(option: WeavlyModel.Option)
# Offered options were updated in place: their text, state or hidden flag may have changed.
signal options_refreshed
# Fires only when the stored value differs; old_value is null on an extern's first set.
signal variable_changed(id: String, value: Variant, old_value: Variant)

# How a pool treats nodes shown locked: SHOW counts them toward the limit, EXTRA shows them
# on top of it, HIDE leaves them out.
enum Locked { SHOW, EXTRA, HIDE }

const DRAW_IN_PROGRESS = "Dialogue is already in progress, can't draw from %s."
const UNREGISTERED_FUNCTION = "Function '%s' is declared, but no callable is registered for it."
const DIALOGUE_IN_PROGRESS = "Dialogue is already in progress, can't start for node with ID '%s'."
const MISSING_NODE = "Can't enter node '%s' because it doesn't exist, finishing the dialogue."
const JUMP_CYCLE = "Entered %d nodes without pausing (likely a jump cycle); finishing the dialogue."
const DETOUR_TOO_DEEP = "Can't detour to node '%s' past %d running nodes; finishing the dialogue."
const NOT_HELD = "release() was called without a matching hold()."
const UNKNOWN_STATE_VERSION = "Can't load a state of version '%s', expected version %d."
const MISSING_SAVED_NODE = "Can't resume at node '%s' because it no longer exists."
const RENDER_IN_PROGRESS = "Dialogue is already in progress, can't render node '%s'."
const CHOOSE_IN_PROGRESS = "Dialogue is already in progress, can't choose option '%s'."
const NOT_OFFERED = "Can't choose option '%s' because it isn't offered right now."
const LOCKED_OPTION = "Can't choose option '%s' because it's locked."
const NOT_A_SERVICE = "Custom service '%s' doesn't extend a service, so it isn't used."
const DUPLICATE_SERVICE = "Custom services '%s' and '%s' both replace %s; only the first is used."
const UNDEFINED_VARIABLE = "Variable '%s' isn't defined."
const UNDEFINED_EXTERN = "Variable '%s' is declared extern but was never defined."
const MISSING_VALUE = "Variable '%s' has no value."
const WRONG_STORED_TYPE = "Variable '%s' holds a value of type '%s' instead of a %s."
const UNKNOWN_STORED_NAME = "Variable '%s' holds '%s', but no %s has that name."
const UNDECLARED_VARIABLE = "Can't set variable '%s' because it isn't declared."
const WRONG_TYPE = "Can't set variable '%s' to a value of type '%s' because it's a %s."
const UNKNOWN_NAME = "Can't set variable '%s' to '%s' because no %s has that name."
const WRONG_SAVED_TYPE = "Saved variable '%s' is skipped because it holds a '%s' instead of a %s."
const UNKNOWN_SAVED_NAME = "Saved variable '%s' is skipped because %s '%s' no longer exists."

const STATE_VERSION = 4
const KEY_VERSION = "version"
const KEY_NODE = "node"
const KEY_SERVICES = "services"
const KEY_RNG = "rng"

static var _default_services: Dictionary[Script, Script] = {
	WeavlyCharacterService: WeavlyDefaultCharacterService,
	WeavlyCountService: WeavlyDefaultCountService,
	WeavlyFunctionService: WeavlyDefaultFunctionService,
	WeavlyLineService: WeavlyDefaultLineService,
	WeavlyVariableService: WeavlyDefaultVariableService,
}

## Scripts that replace default services, each extending a service or a default implementation.
## Set before the engine enters the tree.
@export var custom_services: Array[Script] = []

@export_group("Dialogue")
@export var dialogue_path: String = "res://dialogue/build"
## 0 picks a new seed on every run.
@export var random_seed: int = 0

@export_group("Characters")
## Empty means the game has no character resources.
@export var character_path: String = ""

@export_group("Limits")
@export var max_node_entries_per_step: int = 10000
## How many nodes can run at once through detours, drawn and chosen nodes.
@export var max_detour_depth: int = 64

# The compiled story; services read it, and only loading adds to it.
var story: WeavlyStory = WeavlyStory.new()

var character_service: WeavlyCharacterService
var count_service: WeavlyCountService
var function_service: WeavlyFunctionService
var line_service: WeavlyLineService
var variable_service: WeavlyVariableService

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
# The options of the last renders, which choose() and render_option() accept while the game
# holds them.
var _rendered_options: Array[WeakRef] = []
# get_option's results, refreshed while the game holds them.
var _listed_options: Array[WeakRef] = []
var _registrations_checked: bool = false
# Node id -> meta values taken when it was chosen; meta reads use them while it runs.
var _meta_snapshots: Dictionary[String, Dictionary] = {}
# The running statement lists, bottom to top: node bodies and the blocks inside them.
var _frames: Array[Frame] = []
var _paused: bool = false
var _pending_options: Array[WeavlyModel.Option] = []

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
	_create_services()
	WeavlyFileUtils.load_dialogue(self, dialogue_path)
	_check_variables()
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


# Runs the whole node without pausing and returns filled copies of its lines, do statements
# and option blocks. State changes, visits and entered_node happen as in normal play.
func render(node_id: String) -> Array[WeavlyModel.Statement]:
	if not _finished:
		push_warning(RENDER_IN_PROGRESS % node_id)
		return []
	_check_registrations()
	_begin_render()
	enter_node(node_id)
	return _end_render()


# Runs a chosen option like render(), following jumps into other nodes. A refused option
# returns nothing; can_choose() tells it apart from an option without lines.
func render_option(option: WeavlyModel.Option) -> Array[WeavlyModel.Statement]:
	var refusal: String = CHOOSE_IN_PROGRESS % option.text if not _finished else _refusal(option)
	if refusal != "":
		push_warning(refusal)
		return []
	_rendered_options.clear()
	option_chosen.emit(option)
	_begin_render()
	_run_choice(option)
	return _end_render()


# An offered option runs in the dialogue: a node option like a detour, an inline option's
# body in place. A rendered option or one from get_option starts a dialogue: an inline option
# runs only its body, since the rest of its node already ran; a node option runs its node.
func choose(option: WeavlyModel.Option) -> bool:
	var refusal: String = _refusal(option)
	if refusal != "":
		push_warning(refusal)
		return false
	if _pending_options.has(option):
		_pending_options.clear()
		option_chosen.emit(option)
		if option.item != null:
			add_statements(option.item.body)
			next()
		else:
			snapshot_meta(option.node_id)
			detour(option.node_id)
		return true
	_rendered_options.clear()
	option_chosen.emit(option)
	_finished = false
	started_dialogue.emit()
	_run_choice(option)
	return true


func can_choose(option: WeavlyModel.Option) -> bool:
	return _refusal(option) == ""


# Empty when the option can be chosen now: it's offered, pending or rendered or from get_option,
# and still choosable when checked again.
func _refusal(option: WeavlyModel.Option) -> String:
	if not _offered_options().has(option):
		return NOT_OFFERED % option.text
	if not _finished and not _pending_options.has(option):
		return CHOOSE_IN_PROGRESS % option.text
	var rng_state: int = rng.state
	WeavlyOptionBuilder.refresh(option, self)
	rng.state = rng_state
	if not option.is_choosable():
		return LOCKED_OPTION % option.text
	return ""


func _run_choice(option: WeavlyModel.Option) -> void:
	if option.item == null:
		snapshot_meta(option.node_id)
		enter_node(option.node_id)
		return
	current_source = option.source
	current_line = option.line
	_frames.clear()
	add_statements(option.item.body)
	next()


func _begin_render() -> void:
	_rendered_options = _rendered_options.filter(_is_held)
	_rendering = true
	_render_output = []
	_finished = false
	clear_location()


func _end_render() -> Array[WeavlyModel.Statement]:
	var output: Array[WeavlyModel.Statement] = _render_output
	_rendering = false
	_render_output = []
	_finished = true
	_pending_node_id = null
	_location_stack.clear()
	_meta_snapshots.clear()
	clear_location()
	_frames.clear()
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


# Called from a handler while a step runs, it lets that step continue.
func next() -> void:
	if _holds > 0:
		return
	if not _pending_options.any(
		func(option: WeavlyModel.Option) -> bool: return option.is_choosable()
	):
		_pending_options.clear()
	_paused = false
	if _in_next:
		return
	_in_next = true
	var node_entries: int = 0
	while not _paused and _holds == 0 and _pending_options.is_empty() and not _finished:
		if _pending_node_id != null:
			node_entries += 1
			if node_entries > max_node_entries_per_step:
				report_error(JUMP_CYCLE % max_node_entries_per_step)
				finish()
				break
			_enter_pending_node()
		else:
			_advance()
	_in_next = false
	_refresh_stale_options()


# Runs the top frame's next statement, or leaves the frame once it ran out.
func _advance() -> void:
	if _frames.is_empty():
		finish()
		return
	var frame: Frame = _frames.back()
	if not frame.has_next():
		_frames.pop_back()
		if frame.ends_node:
			leave_current_node()
		return
	WeavlyStatementExecutor.execute_statement(frame.get_current_statement(), self)
	frame.increase_counter()


func _refresh_stale_options() -> void:
	if _options_stale:
		_options_stale = false
		refresh_options()


func _enter_pending_node() -> void:
	var node_id: String = _pending_node_id
	var detoured: bool = _pending_detour
	_pending_node_id = null
	_pending_detour = false
	if not story.has_node(node_id):
		report_error(MISSING_NODE % node_id)
		finish()
		return
	var node: WeavlyModel.WeavlyNode = story.get_node(node_id)
	if not detoured:
		_location_stack.clear()
		_frames.clear()
		if not _rendering:
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
	var frame: Frame = Frame.new(node.body)
	frame.ends_node = true
	_frames.push_back(frame)
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
	_frames.clear()
	_pending_options.clear()


func is_running() -> bool:
	return not _finished


# While a dialogue runs, the state as its current node was entered, so loading replays that node.
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
	var services: Dictionary[String, WeavlyService] = _services()
	for slot: String in services:
		var service_state: Variant = service_states.get(slot, {})
		services[slot].set_state(service_state if service_state is Dictionary else {})
	_check_variables()
	var rng_state: Variant = state.get(KEY_RNG)
	if rng_state is String:
		rng.state = rng_state.to_int()
	state_loaded.emit()

	var node_id: Variant = state.get(KEY_NODE)
	if node_id is not String:
		return
	if not story.has_node(node_id):
		push_error(MISSING_SAVED_NODE % node_id)
		return
	start(node_id)


func reset_state() -> void:
	set_state(_initial_state.duplicate(true))


func _services() -> Dictionary[String, WeavlyService]:
	return {
		"character": character_service,
		"count": count_service,
		"function": function_service,
		"line": line_service,
		"variable": variable_service,
	}


func _collect_service_states() -> Dictionary:
	var states: Dictionary = {}
	var services: Dictionary[String, WeavlyService] = _services()
	for slot: String in services:
		var state: Dictionary = services[slot].get_state()
		if not state.is_empty():
			states[slot] = state
	return states


func hold() -> void:
	if _holds == 0:
		_hold_interrupted_step = _in_next
	_holds += 1


# The last release continues only a step the hold interrupted; a line on screen keeps waiting.
func release() -> void:
	if _holds == 0:
		push_warning(NOT_HELD)
		return
	_holds -= 1
	if _holds > 0 or not _hold_interrupted_step:
		return
	_hold_interrupted_step = false
	if not _in_next and not _paused:
		next()


func is_rendering() -> bool:
	return _rendering


# While rendering, the executor collects filled lines, do statements and option blocks here.
func add_rendered(statement: WeavlyModel.Statement) -> void:
	_render_output.append(statement)
	if statement is WeavlyModel.OptionBlock:
		for option: WeavlyModel.Option in statement.options:
			_rendered_options.append(weakref(option))


# Runs the statements before the rest of the current ones.
func add_statements(statements: Array[WeavlyModel.Statement]) -> void:
	_frames.push_back(Frame.new(statements))


# Runs the groups one after another, first to last, before the rest of the current statements.
func add_statement_groups(groups: Array[Array]) -> void:
	for i: int in range(groups.size() - 1, -1, -1):
		add_statements(groups[i])


# A filled line in play: it waits for next() when the line service says so.
func reach_line(line: WeavlyModel.LineStatement) -> void:
	if line_service.waits(line):
		_paused = true
	line_reached.emit(line)


# The dialogue waits for one of the options to be chosen.
func offer_options(options: Array[WeavlyModel.Option]) -> void:
	_pending_options = options
	options_offered.emit(options)


# The options the dialogue waits on, as options_offered passed them.
func get_pending_options() -> Array[WeavlyModel.Option]:
	return _pending_options.duplicate()


# The value, checked against the declaration; null once an error is reported.
func get_variable(id: String) -> Variant:
	var variable: WeavlyModel.Variable = story.get_variable(id)
	if variable == null:
		report_error(UNDEFINED_VARIABLE % id)
		return null
	if not variable_service.has(id):
		report_error((UNDEFINED_EXTERN if variable.extern else MISSING_VALUE) % id)
		return null
	var value: Variant = WeavlyExpressionEvaluator.fit(
		variable_service.get_value(id),
		variable.get_type_name(),
		id,
		WRONG_STORED_TYPE,
		UNKNOWN_STORED_NAME,
		self
	)
	return null if WeavlyExpressionEvaluator.is_error(value) else value


# Checked against the declaration: the type, a declared name and a number's range.
func set_variable(id: String, value: Variant) -> void:
	var variable: WeavlyModel.Variable = story.get_variable(id)
	if variable == null:
		report_error(UNDECLARED_VARIABLE % id)
		return
	value = WeavlyExpressionEvaluator.fit(
		value, variable.get_type_name(), id, WRONG_TYPE, UNKNOWN_NAME, self
	)
	if WeavlyExpressionEvaluator.is_error(value):
		return
	if variable is WeavlyModel.NumberVariable:
		value = variable.clamp_value(value)
	var old_value: Variant = variable_service.get_value(id) if variable_service.has(id) else null
	variable_service.set_value(id, value)
	if _same(value, old_value):
		return
	variable_changed.emit(id, value, old_value)
	if _in_next or _rendering:
		_options_stale = true
	else:
		refresh_options()


# The callable gets the arguments in declaration order. In an expression it may run any number
# of times and in no fixed order; a do statement runs it exactly once, and only then may it
# change state or wait with hold() and release().
func register_function(name: String, callable: Callable) -> void:
	if WeavlyModel.Signature.can_register(name, callable, story.get_function(name)):
		function_service.register_function(name, callable)


# Calls the function with the statement's values; a rendered one is run by the UI.
func run_do(statement: WeavlyModel.DoStatement) -> void:
	WeavlyExpressionEvaluator.call_function(statement.id, statement.values, self)


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
		_listed_options = _listed_options.filter(_is_held)
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
	options_refreshed.emit()


func _offered_options() -> Array[WeavlyModel.Option]:
	var options: Array[WeavlyModel.Option] = get_pending_options()
	for held: WeakRef in _rendered_options + _listed_options:
		var option: WeavlyModel.Option = held.get_ref()
		if option != null:
			options.append(option)
	return options


static func _is_held(held: WeakRef) -> bool:
	return held.get_ref() != null


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


func report_error(message: String) -> void:
	push_error(_locate(message))
	runtime_error.emit(message, current_source, current_line)


func set_location(node: WeavlyModel.WeavlyNode) -> void:
	current_source = node.source
	current_line = node.line


func clear_location() -> void:
	current_source = ""
	current_line = 0


# Calls evaluate with errors pointing to line in source, then restores the location.
func evaluate_at(source: String, line: int, evaluate: Callable) -> Variant:
	var left_source: String = current_source
	var left_line: int = current_line
	current_source = source
	current_line = line
	var value: Variant = evaluate.call()
	current_source = left_source
	current_line = left_line
	return value


func _locate(message: String) -> String:
	if current_source != "" and current_line > 0:
		return "%s:%d: error: %s" % [current_source, current_line, message]
	return message


func get_meta_snapshot(node_id: String) -> Dictionary:
	return _meta_snapshots.get(node_id, {})


# Freezes the chosen node's meta values for as long as it runs.
func snapshot_meta(node_id: String) -> void:
	_meta_snapshots[node_id] = WeavlyMetaReader.snapshot(self, story.get_node(node_id))


func get_location_stack() -> Array[String]:
	return _location_stack.duplicate()


# Counts a visit to the current node and returns to the node below it.
func leave_current_node() -> void:
	if _location_stack.is_empty():
		return
	var node_id: String = _location_stack.pop_back()
	_meta_snapshots.erase(node_id)
	count_service.record_visit(node_id)
	if not _location_stack.is_empty():
		set_location(story.get_node(current_node_id))
	left_node.emit(node_id)


func leave_all_nodes() -> void:
	while not _location_stack.is_empty():
		leave_current_node()


func _create_services() -> void:
	var scripts: Dictionary[Script, Script] = _default_services.duplicate()
	for script: Script in custom_services:
		if script == null:
			continue
		var service: Script = _service_of(script)
		if service == null:
			push_error(NOT_A_SERVICE % script.resource_path)
		elif scripts[service] != _default_services[service]:
			push_error(
				(
					DUPLICATE_SERVICE
					% [
						scripts[service].resource_path,
						script.resource_path,
						service.get_global_name()
					]
				)
			)
		else:
			scripts[service] = script
	character_service = _new_service(scripts, WeavlyCharacterService)
	count_service = _new_service(scripts, WeavlyCountService)
	function_service = _new_service(scripts, WeavlyFunctionService)
	line_service = _new_service(scripts, WeavlyLineService)
	variable_service = _new_service(scripts, WeavlyVariableService)


func _new_service(scripts: Dictionary[Script, Script], service: Script) -> WeavlyService:
	var instance: WeavlyService = scripts[service].new()
	instance.initialize(self)
	return instance


# The service a script replaces, or null when it extends none.
static func _service_of(script: Script) -> Script:
	var base: Script = script
	while base != null and not _default_services.has(base):
		base = base.get_base_script()
	return base


# Gives every story-owned variable a value that fits its declaration: the default when it has
# none or a saved one doesn't fit, and a number clamped to its range.
func _check_variables() -> void:
	for id: String in story.get_variable_ids():
		var variable: WeavlyModel.Variable = story.get_variable(id)
		if variable.extern:
			continue
		if not variable_service.has(id):
			variable_service.set_value(id, variable.value)
			continue
		var stored: Variant = variable_service.get_value(id)
		var value: Variant = stored
		if variable is WeavlyModel.NumberVariable and value is int:
			value = float(value)
		var type: String = variable.get_type_name()
		match story.fit(type, value):
			WeavlyStory.Fit.WRONG_TYPE:
				push_warning(WRONG_SAVED_TYPE % [id, type_string(typeof(value)), type])
				value = variable.value
			WeavlyStory.Fit.UNKNOWN_NAME:
				push_warning(UNKNOWN_SAVED_NAME % [id, type, value])
				value = variable.value
		if variable is WeavlyModel.NumberVariable:
			value = variable.clamp_value(value)
		if not _same(value, stored):
			variable_service.set_value(id, value)


static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


class Frame:
	extends RefCounted
	var ends_node: bool = false
	var _statements: Array[WeavlyModel.Statement]
	var _counter: int = 0

	func _init(statements: Array[WeavlyModel.Statement]) -> void:
		_statements = statements

	func has_next() -> bool:
		return _counter < _statements.size()

	func get_current_statement() -> WeavlyModel.Statement:
		return _statements[_counter]

	func increase_counter() -> void:
		_counter += 1
