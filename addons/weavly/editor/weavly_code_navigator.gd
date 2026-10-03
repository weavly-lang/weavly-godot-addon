@tool
class_name WeavlyCodeNavigator
extends PopupMenu

const KIND_NAMES: Dictionary[WeavlyProjectIndex.Kind, String] = {
	WeavlyProjectIndex.Kind.NODE: "node",
	WeavlyProjectIndex.Kind.POOL: "pool",
	WeavlyProjectIndex.Kind.SLOT: "slot",
	WeavlyProjectIndex.Kind.VARIABLE: "variable",
	WeavlyProjectIndex.Kind.META_KEY: "meta key",
	WeavlyProjectIndex.Kind.FUNCTION: "function",
	WeavlyProjectIndex.Kind.COMMAND: "command",
}


class Section:
	extends RefCounted
	var heading: String
	# A pool's or slot's nodes rather than the name's own definition.
	var members: bool
	var definitions: Array[WeavlyProjectIndex.Definition]


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
# Popup item id -> its definition.
var _listed: Array[WeavlyProjectIndex.Definition] = []
var _back: Array[Location] = []
var _forward: Array[Location] = []


func _init(panel: WeavlyEditorPanel, code_edit: WeavlyCodeEdit) -> void:
	_panel = panel
	_code_edit = code_edit
	_code_edit.symbol_lookup_on_click = true
	_code_edit.symbol_validate.connect(_on_symbol_validate)
	_code_edit.symbol_lookup.connect(_on_symbol_lookup)
	_code_edit.text_changed.connect(_on_text_changed)
	_code_edit.gui_input.connect(_on_code_edit_input)
	_code_edit.tooltip_source = tooltip_at
	id_pressed.connect(_on_listed_pressed)


func sections_at(line: int, column: int) -> Array[Section]:
	var sections: Array[Section] = []
	var symbol: WeavlySymbolResolver.Symbol = _symbol_at(line, column)
	if symbol == null:
		return sections
	for kind: WeavlyProjectIndex.Kind in symbol.kinds:
		var section: Section = Section.new()
		section.heading = "%s %s" % [KIND_NAMES[kind], symbol.name]
		section.members = (
			kind == WeavlyProjectIndex.Kind.POOL or kind == WeavlyProjectIndex.Kind.SLOT
		)
		if section.members:
			section.definitions = index.members(kind, symbol.name)
		else:
			section.definitions = index.find(kind, symbol.name)
		if not section.definitions.is_empty():
			sections.append(section)
	return sections


# Each definition's file and source; a pool or slot also counts its nodes.
func tooltip_at(line: int, column: int) -> String:
	var symbol: WeavlySymbolResolver.Symbol = _symbol_at(line, column)
	if symbol == null:
		return ""
	var parts: PackedStringArray = []
	for kind: WeavlyProjectIndex.Kind in symbol.kinds:
		var definitions: Array[WeavlyProjectIndex.Definition] = index.find(kind, symbol.name)
		for definition: WeavlyProjectIndex.Definition in definitions:
			parts.append(
				(
					"%s:%d\n%s"
					% [_display_path(definition.path), definition.line + 1, definition.text]
				)
			)
		if kind != WeavlyProjectIndex.Kind.POOL and kind != WeavlyProjectIndex.Kind.SLOT:
			continue
		var count: int = index.members(kind, symbol.name).size()
		if definitions.is_empty():
			if count == 0:
				continue
			parts.append("%s %s" % [KIND_NAMES[kind], symbol.name])
		parts[-1] += "\n1 node" if count == 1 else "\n%d nodes" % count
	return "\n\n".join(parts)


# Goes to the only definition, or lists them; a pool's or slot's nodes are always listed.
func look_up(line: int, column: int) -> void:
	var sections: Array[Section] = sections_at(line, column)
	if sections.is_empty():
		return
	if sections.size() == 1 and not sections[0].members and sections[0].definitions.size() == 1:
		var definition: WeavlyProjectIndex.Definition = sections[0].definitions[0]
		go_to(definition.path, definition.line)
		return
	clear()
	_listed.clear()
	for section: Section in sections:
		add_separator(section.heading)
		for definition: WeavlyProjectIndex.Definition in section.definitions:
			add_item(
				(
					"%s  %s:%d"
					% [definition.name, _display_path(definition.path), definition.line + 1]
				),
				_listed.size()
			)
			_listed.append(definition)
	position = Vector2i(_code_edit.get_screen_position() + _code_edit.get_local_mouse_position())
	reset_size()
	popup()


func go_to(path: String, line: int) -> void:
	var here: Location = _here()
	if _move_to(Location.new(path, line, 0)):
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


func _symbol_at(line: int, column: int) -> WeavlySymbolResolver.Symbol:
	var symbol: WeavlySymbolResolver.Symbol = WeavlySymbolResolver.resolve(
		_code_edit.text.split("\n"), line, column
	)
	if symbol != null:
		_update_index()
	return symbol


# The open file comes first, so a file just switched away from is read from disk again.
func _update_index() -> void:
	var path: String = _panel.get_current_path()
	if _buffer_stale or path != _indexed_path:
		index.set_open_file(path, _code_edit.text)
		_indexed_path = path
		_buffer_stale = false
	index.scan(_panel.get_project_dir())


func _display_path(path: String) -> String:
	var project_dir: String = _panel.get_project_dir().simplify_path() + "/"
	return path.trim_prefix(project_dir) if path.begins_with(project_dir) else path.get_file()


func _on_symbol_validate(_symbol: String) -> void:
	var at: Vector2i = _code_edit.get_line_column_at_pos(
		Vector2i(_code_edit.get_local_mouse_position())
	)
	_code_edit.set_symbol_lookup_word_as_valid(not sections_at(at.y, at.x).is_empty())


func _on_symbol_lookup(_symbol: String, line: int, column: int) -> void:
	look_up(line, column)


func _on_text_changed() -> void:
	_buffer_stale = true


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
	go_to(_listed[id].path, _listed[id].line)
