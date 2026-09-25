@tool
class_name WeavlyFindBar
extends VBoxContainer

signal replaced_all(count: int)

var _code_edit: CodeEdit
var _find_field: LineEdit
var _find_count: Label
var _match_case: CheckButton
var _replace_row: HBoxContainer
var _replace_field: LineEdit


func _init(code_edit: CodeEdit) -> void:
	_code_edit = code_edit
	visible = false
	_build()


func _build() -> void:
	var find_row: HBoxContainer = HBoxContainer.new()
	add_child(find_row)

	_find_field = LineEdit.new()
	_find_field.placeholder_text = "Find"
	_find_field.custom_minimum_size.x = 240
	_find_field.text_changed.connect(_on_find_text_changed)
	_find_field.gui_input.connect(_on_find_field_input)
	find_row.add_child(_find_field)

	_find_count = Label.new()
	find_row.add_child(_find_count)

	var previous: Button = Button.new()
	previous.text = "Previous"
	previous.pressed.connect(find_previous)
	find_row.add_child(previous)

	var next: Button = Button.new()
	next.text = "Next"
	next.pressed.connect(find_next)
	find_row.add_child(next)

	_match_case = CheckButton.new()
	_match_case.text = "Match case"
	_match_case.toggled.connect(_on_match_case_toggled)
	find_row.add_child(_match_case)

	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	find_row.add_child(close_button)

	_replace_row = HBoxContainer.new()
	add_child(_replace_row)

	_replace_field = LineEdit.new()
	_replace_field.placeholder_text = "Replace"
	_replace_field.custom_minimum_size.x = 240
	_replace_field.gui_input.connect(_on_replace_field_input)
	_replace_row.add_child(_replace_field)

	var replace_button: Button = Button.new()
	replace_button.text = "Replace"
	replace_button.pressed.connect(replace)
	_replace_row.add_child(replace_button)

	var replace_all_button: Button = Button.new()
	replace_all_button.text = "Replace All"
	replace_all_button.pressed.connect(replace_all)
	_replace_row.add_child(replace_all_button)


func open(with_replace: bool) -> void:
	if _code_edit.has_selection() and not _code_edit.get_selected_text().contains("\n"):
		_find_field.text = _code_edit.get_selected_text()
	visible = true
	_replace_row.visible = with_replace
	_find_field.grab_focus()
	_find_field.select_all()
	_code_edit.set_search_text(_find_field.text)
	update_count()


func close() -> void:
	visible = false
	_code_edit.set_search_text("")
	_code_edit.grab_focus()


func _on_find_field_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if event.shift_pressed:
			find_previous()
		else:
			find_next()
		_find_field.accept_event()
	elif event.keycode == KEY_ESCAPE:
		close()
		_find_field.accept_event()


func _on_replace_field_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		replace()
		_replace_field.accept_event()
	elif event.keycode == KEY_ESCAPE:
		close()
		_replace_field.accept_event()


func _on_find_text_changed(text: String) -> void:
	_code_edit.set_search_text(text)
	var line: int = _code_edit.get_caret_line()
	var column: int = _code_edit.get_caret_column()
	if _code_edit.has_selection():
		line = _code_edit.get_selection_from_line()
		column = _code_edit.get_selection_from_column()
	if not _select_match(_code_edit.search(text, _search_flags(), line, column)):
		_code_edit.deselect()
	update_count()


func _on_match_case_toggled(_pressed: bool) -> void:
	_code_edit.set_search_flags(_search_flags())
	_on_find_text_changed(_find_field.text)


func _search_flags() -> int:
	return TextEdit.SEARCH_MATCH_CASE if _match_case.button_pressed else 0


func find_next() -> void:
	var text: String = _find_field.text
	var line: int = _code_edit.get_caret_line()
	var column: int = _code_edit.get_caret_column()
	if _code_edit.has_selection():
		line = _code_edit.get_selection_to_line()
		column = _code_edit.get_selection_to_column()
	_select_match(_code_edit.search(text, _search_flags(), line, column))
	update_count()


func find_previous() -> void:
	var matches: Array[Vector2i] = _find_matches()
	if matches.is_empty():
		return
	var line: int = _code_edit.get_caret_line()
	var column: int = _code_edit.get_caret_column()
	if _code_edit.has_selection():
		line = _code_edit.get_selection_from_line()
		column = _code_edit.get_selection_from_column()
	var previous: Vector2i = matches[-1]
	for found: Vector2i in matches:
		if found.y > line or (found.y == line and found.x >= column):
			break
		previous = found
	_select_match(previous)
	update_count()


func _select_match(found: Vector2i) -> bool:
	if _find_field.text == "" or found.y == -1:
		return false
	_code_edit.select(found.y, found.x, found.y, found.x + _find_field.text.length())
	_code_edit.adjust_viewport_to_caret()
	return true


func replace() -> void:
	if _selected_match() in _find_matches():
		_code_edit.insert_text_at_caret(_replace_field.text)
	find_next()


func replace_all() -> void:
	var matches: Array[Vector2i] = _find_matches()
	if matches.is_empty():
		return
	var length: int = _find_field.text.length()
	_code_edit.begin_complex_operation()
	for i: int in range(matches.size() - 1, -1, -1):
		var found: Vector2i = matches[i]
		_code_edit.remove_text(found.y, found.x, found.y, found.x + length)
		_code_edit.insert_text(_replace_field.text, found.y, found.x)
	_code_edit.end_complex_operation()
	update_count()
	replaced_all.emit(matches.size())


func _selected_match() -> Vector2i:
	if (
		not _code_edit.has_selection()
		or _code_edit.get_selected_text().length() != _find_field.text.length()
	):
		return Vector2i(-1, -1)
	return Vector2i(_code_edit.get_selection_from_column(), _code_edit.get_selection_from_line())


func _find_matches() -> Array[Vector2i]:
	var matches: Array[Vector2i] = []
	var text: String = _find_field.text
	if text == "":
		return matches
	var match_case: bool = _match_case.button_pressed
	for line: int in _code_edit.get_line_count():
		var line_text: String = _code_edit.get_line(line)
		var column: int = line_text.find(text) if match_case else line_text.findn(text)
		while column != -1:
			matches.append(Vector2i(column, line))
			var from: int = column + text.length()
			column = line_text.find(text, from) if match_case else line_text.findn(text, from)
	return matches


func update_count() -> void:
	if _find_field.text == "":
		_find_count.text = ""
		return
	var matches: Array[Vector2i] = _find_matches()
	var current: int = matches.find(_selected_match())
	if matches.is_empty():
		_find_count.text = "No matches"
	elif current == -1:
		_find_count.text = "%d matches" % matches.size()
	else:
		_find_count.text = "%d of %d" % [current + 1, matches.size()]
