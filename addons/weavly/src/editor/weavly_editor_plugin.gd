@tool
extends EditorPlugin

const WEAVLY_IMPORT_PLUGIN = preload("weavly_import_plugin.gd")
const WEAVLY_CREATE_MENU_PLUGIN = preload("weavly_create_menu_plugin.gd")
const PLUGIN_NAME = "Weavly"

var _import_plugin: EditorImportPlugin
var _create_menu_plugin: EditorContextMenuPlugin
var _panel: WeavlyEditorPanel


func _enter_tree() -> void:
	_register_project_settings()
	_register_editor_settings()

	_import_plugin = WEAVLY_IMPORT_PLUGIN.new()
	add_import_plugin(_import_plugin)

	_panel = WeavlyEditorPanel.new()
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


func _make_visible(visible: bool) -> void:
	if _panel != null:
		_panel.visible = visible


func _register_project_settings() -> void:
	var key: String = WeavlyEditorPanel.SETTING_PROJECT_DIR
	var default_value: String = WeavlyEditorPanel.DEFAULT_PROJECT_DIR
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, default_value)
		ProjectSettings.set_initial_value(key, default_value)
		ProjectSettings.save()
	ProjectSettings.add_property_info(
		{"name": key, "type": TYPE_STRING, "hint": PROPERTY_HINT_NONE, "hint_string": ""}
	)


func _register_editor_settings() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var key: String = WeavlyEditorPanel.SETTING_EXECUTABLE
	var default_value: String = WeavlyEditorPanel.DEFAULT_EXECUTABLE
	if not settings.has_setting(key):
		settings.set_setting(key, default_value)
	settings.set_initial_value(key, default_value, false)
	settings.add_property_info(
		{
			"name": key,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_GLOBAL_FILE,
			"hint_string": "",
		}
	)
