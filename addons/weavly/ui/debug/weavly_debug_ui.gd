class_name WeavlyDebugUI
extends WeavlyUI

const DEFAULT_TOGGLE_KEY: Key = KEY_F3
const POOLS_TAB: int = 2
const ERRORS_TAB: int = 3

## Shows and hides the overlay. When the project doesn't define the action, it's added on F3.
@export var toggle_action: StringName = &"weavly_toggle_debug"
## Leaves the overlay out of release builds.
@export var debug_builds_only: bool = true
## Seconds between refreshes of the status, variables and nodes while the overlay shows.
@export var refresh_interval: float = 0.25
## The oldest errors are dropped beyond this count.
@export var max_errors: int = 100

var _refresh_left: float = 0.0
# Peeking evaluates pool conditions, which can report errors, so pools refresh on changes only.
var _pools_dirty: bool = true
var _variable_editors: Dictionary[String, Control] = {}
var _node_rows: Dictionary[String, Array] = {}
var _error_count: int = 0

@onready var _status: Label = %Status
@onready var _tabs: TabContainer = %Tabs
@onready var _variable_grid: GridContainer = %VariableGrid
@onready var _node_filter: LineEdit = %NodeFilter
@onready var _node_grid: GridContainer = %NodeGrid
@onready var _pool_list: VBoxContainer = %PoolList
@onready var _error_list: VBoxContainer = %ErrorList
@onready var _clear_errors: Button = %ClearErrors


func _ready() -> void:
	if debug_builds_only and not OS.is_debug_build():
		visible = false
		set_process(false)
		set_process_unhandled_input(false)
		return
	if toggle_action != &"" and not InputMap.has_action(toggle_action):
		var key: InputEventKey = InputEventKey.new()
		key.keycode = DEFAULT_TOGGLE_KEY
		InputMap.add_action(toggle_action)
		InputMap.action_add_event(toggle_action, key)
	_tabs.tab_changed.connect(func(_tab: int) -> void: _on_changed())
	_node_filter.text_changed.connect(func(_text: String) -> void: _filter_nodes())
	_clear_errors.pressed.connect(clear_errors)
	visibility_changed.connect(_on_changed)
	super()


func _process(delta: float) -> void:
	if not visible or engine == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if is_pressed(event, toggle_action):
		get_viewport().set_input_as_handled()
		visible = not visible


## Updates what the overlay shows; it also refreshes on its own while visible.
func refresh() -> void:
	_refresh_left = refresh_interval
	if engine == null or not is_node_ready():
		return
	_refresh_status()
	_refresh_variables()
	_refresh_nodes()
	if _pools_dirty and _tabs.current_tab == POOLS_TAB:
		_refresh_pools()


func clear_errors() -> void:
	_error_count = 0
	free_children(_error_list)
	_tabs.set_tab_title(ERRORS_TAB, "Errors")


func _engine_signals() -> Array[Array]:
	return [
		[engine.started_dialogue, _on_changed],
		[engine.entered_node, _on_node_entered],
		[engine.finished_dialogue, _on_changed],
		[engine.state_loaded, _on_changed],
		[engine.runtime_error, _on_runtime_error],
		[engine.variable_service.variable_changed, _on_variable_changed],
	]


func _on_engine_attached() -> void:
	_build_variables()
	_build_nodes()
	_pools_dirty = true
	refresh()


func _on_engine_detached() -> void:
	free_children(_variable_grid)
	free_children(_node_grid)
	free_children(_pool_list)
	_variable_editors.clear()
	_node_rows.clear()
	clear_errors()
	_status.text = ""


func _on_changed() -> void:
	_pools_dirty = true
	if visible:
		refresh()


func _on_node_entered(_node_id: String) -> void:
	_on_changed()


func _on_variable_changed(_id: String, _value: Variant) -> void:
	_on_changed()


func _on_runtime_error(message: String, source: String, line: int) -> void:
	var label: Label = Label.new()
	label.text = "%s:%d: %s" % [source, line, message] if source != "" else message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = &"WeavlyDebugError"
	_error_list.add_child(label)
	_error_count += 1
	while _error_list.get_child_count() > max_errors:
		var oldest: Node = _error_list.get_child(0)
		_error_list.remove_child(oldest)
		oldest.queue_free()
	_tabs.set_tab_title(ERRORS_TAB, "Errors (%d)" % _error_count)


func _refresh_status() -> void:
	if not engine.is_running():
		_status.text = "idle"
		return
	var node_id: String = engine.current_node_id if engine.current_node_id != "" else "-"
	_status.text = "running, node %s" % node_id
	if engine.current_source != "":
		_status.text += " at %s:%d" % [engine.current_source, engine.current_line]


func _build_variables() -> void:
	var ids: Array = engine.variable_service.get_all_ids()
	ids.sort()
	for id: String in ids:
		var declaration: WeavlyModel.Variable = engine.variable_service.get_declaration(id)
		var type_name: String = declaration.get_type_name() if declaration != null else ""
		_variable_grid.add_child(_create_label(id))
		_variable_grid.add_child(_create_label(type_name, &"WeavlyDebugMuted"))
		var editor: Control = _create_variable_editor(id, declaration)
		_variable_grid.add_child(editor)
		_variable_editors[id] = editor


func _create_variable_editor(id: String, declaration: WeavlyModel.Variable) -> Control:
	if declaration is WeavlyModel.FlagVariable:
		var check: CheckBox = CheckBox.new()
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(
			func(pressed: bool) -> void:
				engine.variable_service.set_variable(id, pressed)
				refresh()
		)
		return check
	var edit: LineEdit = LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(_text: String) -> void: edit.release_focus())
	edit.focus_exited.connect(_commit_variable.bind(id, edit, declaration))
	return edit


# Text that isn't a number for a number variable is dropped, and the refresh shows the value.
func _commit_variable(id: String, edit: LineEdit, declaration: WeavlyModel.Variable) -> void:
	if declaration is WeavlyModel.NumberVariable:
		if edit.text.strip_edges().is_valid_float():
			engine.variable_service.set_variable(id, edit.text.strip_edges().to_float())
	else:
		engine.variable_service.set_variable(id, edit.text)
	refresh()


# An extern variable joins the list once the game gives it a value.
func _refresh_variables() -> void:
	if engine.variable_service.get_all_ids().size() != _variable_editors.size():
		free_children(_variable_grid)
		_variable_editors.clear()
		_build_variables()
	for id: String in _variable_editors:
		var value: Variant = engine.variable_service.get_variable(id)
		var editor: Control = _variable_editors[id]
		if editor is CheckBox:
			editor.set_pressed_no_signal(bool(value))
			editor.text = str(bool(value))
		elif not editor.has_focus():
			editor.text = _format(value)


# Exact, unlike numbers in dialogue text, with whole numbers shown without decimals.
func _format(value: Variant) -> String:
	if value is float and is_finite(value) and value == floorf(value):
		return str(int(value))
	return str(value)


func _build_nodes() -> void:
	var nodes: Array[WeavlyModel.WeavlyNode] = engine.node_service.get_all_nodes()
	nodes.sort_custom(
		func(a: WeavlyModel.WeavlyNode, b: WeavlyModel.WeavlyNode) -> bool: return a.id < b.id
	)
	for node: WeavlyModel.WeavlyNode in nodes:
		var jump: Button = Button.new()
		jump.text = "Start"
		jump.focus_mode = Control.FOCUS_NONE
		jump.pressed.connect(_jump.bind(node.id))
		var row: Array[Control] = [
			_create_label(node.id),
			_create_label("%s:%d" % [node.source, node.line], &"WeavlyDebugMuted"),
			_create_label(""),
			_create_label(""),
			jump,
		]
		for control: Control in row:
			_node_grid.add_child(control)
		_node_rows[node.id] = row
	_filter_nodes()


func _refresh_nodes() -> void:
	for id: String in _node_rows:
		var row: Array = _node_rows[id]
		(row[2] as Label).text = "%d visits" % engine.node_service.get_visit_count(id)
		(row[3] as Label).text = "%d skips" % engine.node_service.get_skip_count(id)
		var current: bool = engine.is_running() and id == engine.current_node_id
		(row[0] as Label).theme_type_variation = &"WeavlyDebugCurrent" if current else &""


func _filter_nodes() -> void:
	var filter: String = _node_filter.text.strip_edges()
	for id: String in _node_rows:
		var shown: bool = filter == "" or id.containsn(filter)
		for control: Control in _node_rows[id]:
			control.visible = shown


# Ends the running dialogue and starts the node in step mode.
func _jump(node_id: String) -> void:
	if engine.is_running():
		engine.finish()
	engine.start(node_id)
	refresh()


func _refresh_pools() -> void:
	_pools_dirty = false
	free_children(_pool_list)
	var pools: Array[String] = []
	for node: WeavlyModel.WeavlyNode in engine.node_service.get_all_nodes():
		if node.meta == null:
			continue
		for pool: String in node.meta.pools:
			if pool not in pools:
				pools.append(pool)
	pools.sort()
	for pool: String in pools:
		_pool_list.add_child(_create_label(pool, &"WeavlyDebugHeading"))
		var order: Array[String] = engine.peek_pool([pool])
		var text: String = (
			", ".join(PackedStringArray(order)) if not order.is_empty() else "(none)"
		)
		var entries: Label = _create_label(text)
		entries.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pool_list.add_child(entries)


func _create_label(text: String, variation: StringName = &"") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
