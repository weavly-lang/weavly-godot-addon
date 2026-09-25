@tool
class_name WeavlyEditorPanel
extends Control

const SETTING_PROJECT_DIR = "weavly/dialogue_project_dir"
const SETTING_EXECUTABLE = "weavly/executable_path"
const SETTING_COMPILE_ON_SAVE = "weavly/compile_on_save"
const SETTING_LINE_WRAP = "weavly/line_wrap"
const DEFAULT_PROJECT_DIR = "res://dialogue"
const DEFAULT_EXECUTABLE = "weavly"

const _NO_FILE_TEXT = "Double-click a .wvl file in the FileSystem dock to edit it."
const _LOG_PREFIX = "[Weavly]"
const _VERSION_UNKNOWN = (
	"%s Could not read the version of '%s'. Install the Weavly compiler %s or newer with "
	+ "'uv tool install weavly', then restart Godot so it picks up your PATH, or point the "
	+ "editor setting '%s' at the executable."
)
const _VERSION_TOO_OLD = (
	"%s Weavly compiler %s is older than the supported %s. Upgrade it with "
	+ "'uv tool upgrade weavly'."
)

const _COLOR_ERROR = Color(0.94, 0.42, 0.42)
const _COLOR_SUCCESS = Color(0.50, 0.84, 0.52)
const _COLOR_INFO = Color(0.66, 0.74, 0.88)
const _NODE_STRIP_COLORS: Array[Color] = [Color(0.35, 0.56, 0.88), Color(0.88, 0.67, 0.35)]
const _NODE_STRIP_WIDTH = 4
const _NODE_STRIP_GAP = 6

var _path_label: Label
var _node_picker: OptionButton
var _status_label: Label
var _code_edit: CodeEdit
var _compile_on_save: CheckButton
var _line_wrap: CheckButton
var _save_button: Button
var _compile_button: Button
var _find_bar: WeavlyFindBar
var _current_path: String = ""
var _dirty: bool = false
var _compiling: bool = false
var _compile_thread: Thread
var _checked_executable: String = ""
var _node_start_regex: RegEx = RegEx.create_from_string(
	"^[ \\t]*@node[ \\t]+([A-Za-z_][A-Za-z0-9_]*)"
)
var _node_end_regex: RegEx = RegEx.create_from_string("^[ \\t]*@endnode\\b")
var _node_lines: PackedInt32Array = []
var _line_nodes: PackedInt32Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_refresh_controls()


func open_file(path: String) -> void:
	if path == "":
		return
	if _dirty and _current_path != "" and not _save_file():
		return
	var abs_path: String = ProjectSettings.globalize_path(path)
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		_report_error("Could not open %s" % abs_path)
		return
	_current_path = abs_path
	_code_edit.text = file.get_as_text()
	file.close()
	_dirty = false
	_update_nodes()
	if _find_bar.visible:
		_find_bar.update_count()
	_set_status("", _COLOR_INFO)
	_refresh_controls()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	margin.add_child(root)

	var toolbar: HBoxContainer = HBoxContainer.new()
	root.add_child(toolbar)

	_path_label = Label.new()
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(_path_label)

	_node_picker = OptionButton.new()
	_node_picker.tooltip_text = "Go to node"
	_node_picker.item_selected.connect(_on_node_selected)
	toolbar.add_child(_node_picker)

	_status_label = Label.new()
	toolbar.add_child(_status_label)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(_save_button)

	_compile_on_save = CheckButton.new()
	_compile_on_save.text = "Compile on save"
	_compile_on_save.toggled.connect(_on_compile_on_save_toggled)
	toolbar.add_child(_compile_on_save)
	_load_compile_on_save()

	_line_wrap = CheckButton.new()
	_line_wrap.text = "Wrap lines"
	toolbar.add_child(_line_wrap)

	_compile_button = Button.new()
	_compile_button.text = "Compile"
	_compile_button.pressed.connect(_on_compile_pressed)
	toolbar.add_child(_compile_button)

	_code_edit = CodeEdit.new()
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.syntax_highlighter = WvlSyntaxHighlighter.new()
	_code_edit.text_changed.connect(_on_text_changed)
	_code_edit.caret_changed.connect(_sync_node_picker)
	root.add_child(_code_edit)

	var gutter: int = _code_edit.get_gutter_count()
	_code_edit.add_gutter(gutter)
	_code_edit.set_gutter_type(gutter, TextEdit.GUTTER_TYPE_CUSTOM)
	_code_edit.set_gutter_width(gutter, _NODE_STRIP_WIDTH + _NODE_STRIP_GAP)
	_code_edit.set_gutter_custom_draw(gutter, _draw_node_gutter)

	_line_wrap.toggled.connect(_on_line_wrap_toggled)
	_line_wrap.button_pressed = _load_line_wrap()

	_find_bar = WeavlyFindBar.new(_code_edit)
	_find_bar.replaced_all.connect(_on_replaced_all)
	root.add_child(_find_bar)


func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _current_path == "":
		return
	if not (event is InputEventKey and event.pressed):
		return
	var command: bool = (
		event.is_command_or_control_pressed() and not event.shift_pressed and not event.alt_pressed
	)
	if event.keycode == KEY_S and command:
		_on_save_pressed()
		accept_event()
	elif event.keycode == KEY_F and command:
		_find_bar.open(false)
		accept_event()
	elif event.keycode == KEY_H and command:
		_find_bar.open(true)
		accept_event()
	elif event.keycode == KEY_F3 and _find_bar.visible:
		if event.shift_pressed:
			_find_bar.find_previous()
		else:
			_find_bar.find_next()
		accept_event()


func _on_text_changed() -> void:
	_update_nodes()
	if _find_bar.visible:
		_find_bar.update_count()
	if not _dirty:
		_dirty = true
		_refresh_controls()


func _update_nodes() -> void:
	_node_lines.clear()
	_node_picker.clear()
	_line_nodes.resize(_code_edit.get_line_count())
	var node: int = -1
	for line: int in _code_edit.get_line_count():
		var text: String = _code_edit.get_line(line)
		var start: RegExMatch = _node_start_regex.search(text)
		if start != null:
			node = _node_lines.size()
			_node_lines.append(line)
			_node_picker.add_item(start.get_string(1))
		_line_nodes[line] = node
		if _node_end_regex.search(text) != null:
			node = -1
	_node_picker.disabled = _node_lines.is_empty()
	_sync_node_picker()
	_code_edit.queue_redraw()


func _sync_node_picker() -> void:
	var line: int = _code_edit.get_caret_line()
	_node_picker.select(_line_nodes[line] if line < _line_nodes.size() else -1)


func _on_node_selected(index: int) -> void:
	_code_edit.deselect()
	_code_edit.set_caret_line(_node_lines[index])
	_code_edit.set_caret_column(0)
	_code_edit.center_viewport_to_caret()
	_code_edit.grab_focus()


func _draw_node_gutter(line: int, _gutter: int, area: Rect2) -> void:
	if line >= _line_nodes.size() or _line_nodes[line] == -1:
		return
	var color: Color = _NODE_STRIP_COLORS[_line_nodes[line] % _NODE_STRIP_COLORS.size()]
	var strip: Rect2 = Rect2(area.position, Vector2(_NODE_STRIP_WIDTH, area.size.y))
	_code_edit.draw_rect(strip, color)


func _on_replaced_all(count: int) -> void:
	_set_status("Replaced %d" % count, _COLOR_INFO)


func _on_save_pressed() -> void:
	if not _save_file():
		return
	if _compile_on_save.button_pressed:
		_compile()


func _on_compile_pressed() -> void:
	if _current_path != "" and _dirty and not _save_file():
		return
	_compile()


func _save_file() -> bool:
	if _current_path == "":
		return false
	var file: FileAccess = FileAccess.open(_current_path, FileAccess.WRITE)
	if file == null:
		_report_error("Could not write %s" % _current_path)
		return false
	file.store_string(_code_edit.text)
	file.close()
	_dirty = false
	_refresh_controls()
	if Engine.is_editor_hint():
		var localized: String = ProjectSettings.localize_path(_current_path)
		if localized.begins_with("res://"):
			EditorInterface.get_resource_filesystem().update_file(localized)
	return true


func _compile() -> void:
	if _compiling:
		return

	var working_dir: String = _resolve_working_dir()
	if not DirAccess.dir_exists_absolute(working_dir):
		_report_error("Weavly project dir not found: %s" % working_dir)
		return

	var executable: String = _resolve_executable()
	_set_status("Compiling...", _COLOR_INFO)
	print_rich("%s Running %s build in %s" % [_LOG_PREFIX, executable, working_dir])

	_set_compiling(true)
	_compile_thread = Thread.new()
	_compile_thread.start(_compile_worker.bind(executable, working_dir))


func _compile_worker(executable: String, working_dir: String) -> void:
	var version: String = ""
	if executable != _checked_executable:
		version = WeavlyCompilerRunner.get_version(executable)
	var result: WeavlyCompilerRunner.CompileResult = WeavlyCompilerRunner.compile(
		executable, working_dir
	)
	_on_compile_finished.call_deferred(result, executable, version)


func _on_compile_finished(
	result: WeavlyCompilerRunner.CompileResult, executable: String, version: String
) -> void:
	_join_compile_thread()
	_set_compiling(false)
	if executable != _checked_executable:
		_checked_executable = executable
		_report_version(executable, version)
	if result.success:
		_set_status("Build successful", _COLOR_SUCCESS)
		var message: String = result.output if result.output != "" else "Build successful."
		print_rich("[color=#80d685]%s %s[/color]" % [_LOG_PREFIX, message])
		_rescan_filesystem()
	else:
		_report_failure(result)


func _report_version(executable: String, version: String) -> void:
	var minimum: String = WeavlyCompilerRunner.MINIMUM_VERSION
	if version == "":
		push_warning(_VERSION_UNKNOWN % [_LOG_PREFIX, executable, minimum, SETTING_EXECUTABLE])
	elif not WeavlyCompilerRunner.is_version_supported(version):
		push_warning(_VERSION_TOO_OLD % [_LOG_PREFIX, version, minimum])


func _set_compiling(compiling: bool) -> void:
	_compiling = compiling
	_refresh_controls()


func _report_failure(result: WeavlyCompilerRunner.CompileResult) -> void:
	_set_status("Build failed - see Output", _COLOR_ERROR)
	push_error("%s Build failed (exit code %d)." % [_LOG_PREFIX, result.exit_code])
	if result.output != "":
		print(result.output)
	var error: WeavlyCompilerRunner.CompileError = _first_error_in_open_file(result)
	if error != null:
		_code_edit.set_caret_line(error.line - 1)
		_code_edit.set_caret_column(maxi(error.column - 1, 0))
		_code_edit.grab_focus()


func _rescan_filesystem() -> void:
	if not Engine.is_editor_hint():
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if not filesystem.is_scanning():
		filesystem.scan()


func _first_error_in_open_file(
	result: WeavlyCompilerRunner.CompileResult
) -> WeavlyCompilerRunner.CompileError:
	if _current_path == "":
		return null
	var open_path: String = _current_path.simplify_path()
	for error: WeavlyCompilerRunner.CompileError in result.errors:
		if error.file.simplify_path() == open_path:
			return error
	return null


func _resolve_working_dir() -> String:
	var dir: String = DEFAULT_PROJECT_DIR
	if ProjectSettings.has_setting(SETTING_PROJECT_DIR):
		dir = ProjectSettings.get_setting(SETTING_PROJECT_DIR)
	return ProjectSettings.globalize_path(dir)


func _resolve_executable() -> String:
	if not Engine.is_editor_hint():
		return DEFAULT_EXECUTABLE
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings.has_setting(SETTING_EXECUTABLE):
		return settings.get_setting(SETTING_EXECUTABLE)
	return DEFAULT_EXECUTABLE


func _refresh_controls() -> void:
	var has_file: bool = _current_path != ""
	_save_button.disabled = not has_file or _compiling
	if _compile_button != null:
		_compile_button.disabled = _compiling
	if not has_file:
		_path_label.text = _NO_FILE_TEXT
		return
	var marker: String = "*" if _dirty else ""
	_path_label.text = "%s%s" % [_current_path, marker]


func _load_compile_on_save() -> void:
	if not Engine.is_editor_hint():
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings.has_setting(SETTING_COMPILE_ON_SAVE):
		_compile_on_save.button_pressed = settings.get_setting(SETTING_COMPILE_ON_SAVE)


func _on_compile_on_save_toggled(pressed: bool) -> void:
	if not Engine.is_editor_hint():
		return
	EditorInterface.get_editor_settings().set_setting(SETTING_COMPILE_ON_SAVE, pressed)


func _load_line_wrap() -> bool:
	if not Engine.is_editor_hint():
		return true
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings.has_setting(SETTING_LINE_WRAP):
		return settings.get_setting(SETTING_LINE_WRAP)
	return true


func _on_line_wrap_toggled(pressed: bool) -> void:
	_code_edit.wrap_mode = (
		TextEdit.LINE_WRAPPING_BOUNDARY if pressed else TextEdit.LINE_WRAPPING_NONE
	)
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_setting(SETTING_LINE_WRAP, pressed)


func _join_compile_thread() -> void:
	if _compile_thread != null:
		_compile_thread.wait_to_finish()
		_compile_thread = null


func _exit_tree() -> void:
	_join_compile_thread()


func _set_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)


func _report_error(message: String) -> void:
	_set_status(message, _COLOR_ERROR)
	push_error("%s %s" % [_LOG_PREFIX, message])
