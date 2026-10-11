@tool
extends EditorPlugin

const WEAVLY_IMPORT_PLUGIN = preload("weavly_import_plugin.gd")
const WEAVLY_CREATE_MENU_PLUGIN = preload("weavly_create_menu_plugin.gd")
const PLUGIN_NAME = "Weavly"

var _import_plugin: EditorImportPlugin
var _create_menu_plugin: EditorContextMenuPlugin
var _panel: WeavlyEditorPanel


func _enter_tree() -> void:
	_register_editor_settings()

	_import_plugin = WEAVLY_IMPORT_PLUGIN.new()
	add_import_plugin(_import_plugin)

	_panel = WeavlyEditorPanel.new()
	_panel.file_opened.connect(queue_save_layout)
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)

	_create_menu_plugin = WEAVLY_CREATE_MENU_PLUGIN.new()
	_create_menu_plugin.setup(_panel, PLUGIN_NAME)
	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE, _create_menu_plugin
	)


func _exit_tree() -> void:
	if _create_menu_plugin != null:
		remove_context_menu_plugin(_create_menu_plugin)
		_create_menu_plugin = null
	if _import_plugin != null:
		remove_import_plugin(_import_plugin)
		_import_plugin = null
	if _panel != null:
		_panel.queue_free()
		_panel = null


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return PLUGIN_NAME


func _get_plugin_icon() -> Texture2D:
	var theme: Theme = EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon("Script", "EditorIcons"):
		return theme.get_icon("Script", "EditorIcons")
	return null


func _handles(object: Object) -> bool:
	return object is WeavlySource


func _edit(object: Object) -> void:
	if _panel != null and object is WeavlySource:
		_panel.open_file(object.source_path)


# Godot asks before quitting while this isn't empty; an empty for_scene means the editor closes.
func _get_unsaved_status(for_scene: String) -> String:
	if for_scene != "" or _panel == null:
		return ""
	var path: String = _panel.get_unsaved_path()
	return "" if path == "" else "Save changes to '%s' before closing?" % path.get_file()


# Godot's own save commands, and saving before quitting or running the project.
func _save_external_data() -> void:
	if _panel != null:
		_panel.save_unsaved()


func _get_window_layout(configuration: ConfigFile) -> void:
	if _panel != null:
		_panel.save_layout(configuration)


func _set_window_layout(configuration: ConfigFile) -> void:
	if _panel != null:
		_panel.restore_layout(configuration)


func _make_visible(visible: bool) -> void:
	if _panel != null:
		_panel.visible = visible


func _register_editor_settings() -> void:
	_register_setting(
		WeavlyEditorPanel.SETTING_EXECUTABLE,
		WeavlyEditorPanel.DEFAULT_EXECUTABLE,
		TYPE_STRING,
		PROPERTY_HINT_GLOBAL_FILE
	)
	_register_setting(WeavlyEditorPanel.SETTING_NODE_SEPARATOR, true, TYPE_BOOL)
	_register_setting(WeavlyEditorPanel.SETTING_NODE_TINT, true, TYPE_BOOL)


func _register_setting(
	key: String,
	default_value: Variant,
	type: Variant.Type,
	hint: PropertyHint = PROPERTY_HINT_NONE
) -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if not settings.has_setting(key):
		settings.set_setting(key, default_value)
	settings.set_initial_value(key, default_value, false)
	settings.add_property_info({"name": key, "type": type, "hint": hint, "hint_string": ""})
