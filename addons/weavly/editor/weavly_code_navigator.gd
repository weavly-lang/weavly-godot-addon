@tool
class_name WeavlyCodeNavigator
extends PopupMenu

# Other files changed on disk; the open file's own edits don't emit it.
signal index_changed

# Other files are read from disk again at most this often while hovering.
const RESCAN_INTERVAL_MS = 1000
# A pool's or slot's tooltip names this many of its nodes.
const TOOLTIP_NODES = 10
# A listed use shows this much of its line.
const USE_TEXT_LENGTH = 60
const KIND_NAMES: Dictionary[WeavlyProjectIndex.Kind, String] = {
	WeavlyProjectIndex.Kind.NODE: "node",
	WeavlyProjectIndex.Kind.POOL: "pool",
	WeavlyProjectIndex.Kind.SLOT: "slot",
	WeavlyProjectIndex.Kind.CHARACTER: "character",
	WeavlyProjectIndex.Kind.VARIABLE: "variable",
	WeavlyProjectIndex.Kind.META_KEY: "meta key",
	WeavlyProjectIndex.Kind.FUNCTION: "function",
}


class Section:
	extends RefCounted
	var heading: String
	# The name's own definitions rather than nodes or uses to choose from.
	var definitions: bool
	var entries: Array[Location] = []
	var labels: PackedStringArray = []

	func _init(section_heading: String, are_definitions: bool) -> void:
		heading = section_heading
		definitions = are_definitions


class Location:
	extends RefCounted
	var path: String
	var line: int
	var column: int

	func _init(location_path: String, location_line: int, location_column: int) -> void:
		path = location_path
		line = location_line
		column = location_column


var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
var _panel: WeavlyEditorPanel
var _code_edit: WeavlyCodeEdit
var _indexed_path: String = ""
var _buffer_stale: bool = true
var _lines: PackedStringArray = []
var _lines_stale: bool = true
var _scanned_at: int = -RESCAN_INTERVAL_MS
# Popup item id -> where it goes.
var _listed: Array[Location] = []
var _back: Array[Location] = []
var _forward: Array[Location] = []


func _init(panel: WeavlyEditorPanel, code_edit: WeavlyCodeEdit) -> void:
	_panel = panel
	_code_edit = code_edit
	_code_edit.symbol_lookup_on_click = true
	_code_edit.symbol_validate.connect(_on_symbol_validate)
	_code_edit.symbol_lookup.connect(_on_symbol_lookup)
	_code_edit.text_changed.connect(_on_text_changed)
	_code_edit.text_set.connect(_on_text_changed)
	_code_edit.gui_input.connect(_on_code_edit_input)
	_code_edit.tooltip_source = tooltip_at
	id_pressed.connect(_on_listed_pressed)


# A use lists its definitions, a declaration its uses; a pool or slot adds its nodes.
func sections_at(line: int, column: int) -> Array[Section]:
	var sections: Array[Section] = []
	var symbol: WeavlySymbolResolver.Symbol = _symbol_at(line, column)
	if symbol == null:
		return sections
	if symbol.role == WeavlySymbolResolver.Role.DECLARATION:
		var kind: WeavlyProjectIndex.Kind = symbol.kinds[0]
		if _is_group(kind):
			_add_definitions(sections, "nodes in " + symbol.name, index.members(kind, symbol.name))
		var uses: Section = Section.new("uses of " + symbol.name, false)
		for use: WeavlyProjectIndex.Use in index.uses(kind, symbol.name):
			var text: String = use.text
			if text.length() > USE_TEXT_LENGTH:
				text = text.left(USE_TEXT_LENGTH - 3) + "..."
			uses.entries.append(Location.new(use.path, use.line, use.column))
			uses.labels.append("%s:%d  %s" % [_display_path(use.path), use.line + 1, text])
		sections.append(uses)
		return sections
	for kind: WeavlyProjectIndex.Kind in symbol.kinds:
		_add_definitions(
			sections,
			"%s %s" % [KIND_NAMES[kind], symbol.name],
			index.find(kind, symbol.name),
			true
		)
		if _is_group(kind):
			_add_definitions(sections, "nodes in " + symbol.name, index.members(kind, symbol.name))
	return sections


func _add_definitions(
	sections: Array[Section],
	heading: String,
	definitions: Array[WeavlyProjectIndex.Definition],
	own: bool = false
) -> void:
	if definitions.is_empty():
		return
	var section: Section = Section.new(heading, own)
	for definition: WeavlyProjectIndex.Definition in definitions:
		section.entries.append(Location.new(definition.path, definition.line, 0))
		section.labels.append(
			"%s  %s:%d" % [definition.name, _display_path(definition.path), definition.line + 1]
		)
	sections.append(section)


# Each definition's file and source, a pool's or slot's nodes, and how often the name is used.
func tooltip_at(line: int, column: int) -> String:
	var symbol: WeavlySymbolResolver.Symbol = _symbol_at(line, column)
	if symbol == null:
		return ""
	var parts: PackedStringArray = []
	for kind: WeavlyProjectIndex.Kind in symbol.kinds:
		var definitions: Array[WeavlyProjectIndex.Definition] = index.find(kind, symbol.name)
		var nodes: Array[WeavlyProjectIndex.Definition] = []
		if _is_group(kind):
			nodes = index.members(kind, symbol.name)
		if definitions.is_empty() and nodes.is_empty():
			continue
		for definition: WeavlyProjectIndex.Definition in definitions:
			parts.append(
				(
					"%s:%d\n%s"
					% [_display_path(definition.path), definition.line + 1, definition.text]
				)
			)
		if definitions.is_empty():
			parts.append("%s %s" % [KIND_NAMES[kind], symbol.name])
		if _is_group(kind):
			parts[-1] += "\n" + _node_names(nodes)
		parts[-1] += "\n" + _use_count(index.uses(kind, symbol.name))
	return "\n\n".join(parts)


func _node_names(nodes: Array[WeavlyProjectIndex.Definition]) -> String:
	if nodes.is_empty():
		return "no nodes"
	var names: PackedStringArray = []
	for node: WeavlyProjectIndex.Definition in nodes.slice(0, TOOLTIP_NODES):
		names.append(node.name)
	var more: int = nodes.size() - names.size()
	return "nodes: " + ", ".join(names) + ("" if more == 0 else " and %d more" % more)


func _use_count(uses: Array[WeavlyProjectIndex.Use]) -> String:
	if uses.is_empty():
		return "no uses"
	var files: Dictionary[String, bool] = {}
	for use: WeavlyProjectIndex.Use in uses:
		files[use.path] = true
	return (
		"%d %s in %d %s"
		% [
			uses.size(),
			"use" if uses.size() == 1 else "uses",
			files.size(),
			"file" if files.size() == 1 else "files",
		]
	)


# Goes to the only definition, or lists what there is to choose from.
func look_up(line: int, column: int) -> void:
	var sections: Array[Section] = sections_at(line, column)
	if sections.is_empty():
		return
	if sections.size() == 1 and sections[0].definitions and sections[0].entries.size() == 1:
		go_to(sections[0].entries[0])
		return
	clear()
	_listed.clear()
	for section: Section in sections:
		add_separator(section.heading)
		if section.entries.is_empty():
			add_item("none", _listed.size())
			set_item_disabled(item_count - 1, true)
			_listed.append(null)
		for i: int in section.entries.size():
			add_item(section.labels[i], _listed.size())
			_listed.append(section.entries[i])
	position = Vector2i(_code_edit.get_screen_position() + _code_edit.get_local_mouse_position())
	reset_size()
	popup()


func go_to(location: Location) -> void:
	var here: Location = _here()
	if _move_to(location):
		_back.append(here)
		_forward.clear()


func back() -> void:
	_step(_back, _forward)


func forward() -> void:
	_step(_forward, _back)


func _step(from: Array[Location], to: Array[Location]) -> void:
	if from.is_empty():
		return
	var here: Location = _here()
	if _move_to(from.back()):
		from.pop_back()
		to.append(here)


func _here() -> Location:
	return Location.new(
		_panel.get_current_path(), _code_edit.get_caret_line(), _code_edit.get_caret_column()
	)


func _move_to(location: Location) -> bool:
	if location.path.simplify_path() != _panel.get_current_path().simplify_path():
		if not _panel.open_file(location.path):
			return false
	_code_edit.deselect()
	_code_edit.set_caret_line(location.line)
	_code_edit.set_caret_column(location.column)
	_code_edit.center_viewport_to_caret()
	_code_edit.grab_focus()
	return true


# The kind of what the name is defined as in the project, or -1.
func kind_of(name: String) -> int:
	_update_index()
	return index.kind_of(name)


func _symbol_at(line: int, column: int) -> WeavlySymbolResolver.Symbol:
	if _lines_stale:
		_lines = _code_edit.text.split("\n")
		_lines_stale = false
	var symbol: WeavlySymbolResolver.Symbol = WeavlySymbolResolver.resolve(_lines, line, column)
	if symbol != null:
		_update_index()
	return symbol


# The open file comes first, so a file just switched away from is read from disk again.
func _update_index() -> void:
	var path: String = _panel.get_current_path()
	var switched: bool = path != _indexed_path
	if _buffer_stale or switched:
		index.set_open_file(path, _code_edit.text)
		_indexed_path = path
		_buffer_stale = false
	var now: int = Time.get_ticks_msec()
	if switched or now - _scanned_at >= RESCAN_INTERVAL_MS:
		_scanned_at = now
		if index.scan(_panel.get_project_dir()) and not switched:
			index_changed.emit()


static func _is_group(kind: WeavlyProjectIndex.Kind) -> bool:
	return kind == WeavlyProjectIndex.Kind.POOL or kind == WeavlyProjectIndex.Kind.SLOT


func _display_path(path: String) -> String:
	var project_dir: String = _panel.get_project_dir()
	if project_dir == "" or not path.begins_with(project_dir.simplify_path() + "/"):
		return path.get_file()
	return path.trim_prefix(project_dir.simplify_path() + "/")


func _on_symbol_validate(_symbol: String) -> void:
	var at: Vector2i = _code_edit.get_line_column_at_pos(
		Vector2i(_code_edit.get_local_mouse_position())
	)
	_code_edit.set_symbol_lookup_word_as_valid(not sections_at(at.y, at.x).is_empty())


func _on_symbol_lookup(_symbol: String, line: int, column: int) -> void:
	look_up(line, column)


func _on_text_changed() -> void:
	_buffer_stale = true
	_lines_stale = true


func _on_code_edit_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_XBUTTON1:
		back()
		_code_edit.accept_event()
	elif event.button_index == MOUSE_BUTTON_XBUTTON2:
		forward()
		_code_edit.accept_event()


func _on_listed_pressed(id: int) -> void:
	go_to(_listed[id])
