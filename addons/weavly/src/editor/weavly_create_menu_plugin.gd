@tool
extends EditorContextMenuPlugin

const _MENU_LABEL = "WeavlyFile..."
const _DEFAULT_NAME = "new_dialog"
const _EXTENSION = ".wvl"
const _TEMPLATE = "@node first_node\nHello World!\n@endnode\n"

var _panel: WeavlyEditorPanel
var _main_screen_name: String = ""


func setup(panel: WeavlyEditorPanel, main_screen_name: String) -> void:
	_panel = panel
	_main_screen_name = main_screen_name


func _popup_menu(_paths: PackedStringArray) -> void:
	add_context_menu_item(_MENU_LABEL, _on_create)


func _on_create(paths: Variant) -> void:
	var folder: String = _resolve_folder(paths)
	if folder == "":
		return

	var path: String = _unique_path(folder)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[Weavly] Could not create %s" % path)
		return
	file.store_string(_TEMPLATE)
	file.close()

	EditorInterface.get_resource_filesystem().scan()
	if _panel != null:
		_panel.open_file(path)
	if _main_screen_name != "":
		EditorInterface.set_main_screen_editor(_main_screen_name)


func _resolve_folder(paths: Variant) -> String:
	var candidate: String = ""
	if (paths is PackedStringArray or paths is Array) and paths.size() > 0:
		candidate = str(paths[0])
	elif paths is String:
		candidate = paths
	if candidate == "":
		return ""
	if not DirAccess.dir_exists_absolute(candidate):
		candidate = candidate.get_base_dir()
	return candidate


func _unique_path(folder: String) -> String:
	var base: String = folder.path_join(_DEFAULT_NAME + _EXTENSION)
	if not FileAccess.file_exists(base):
		return base
	for index in range(2, 1000):
		var candidate: String = folder.path_join(
			"%s_%d%s" % [_DEFAULT_NAME, index, _EXTENSION]
		)
		if not FileAccess.file_exists(candidate):
			return candidate
	return base
