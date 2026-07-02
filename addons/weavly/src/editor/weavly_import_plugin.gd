@tool
extends EditorImportPlugin

const RECOGNIZED_EXTENSIONS = ["wvl", "wenvl"]


func _get_importer_name() -> String:
	return "weavly.source"


func _get_visible_name() -> String:
	return "Weavly Source"


func _get_recognized_extensions() -> PackedStringArray:
	return RECOGNIZED_EXTENSIONS


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(
	_path: String, _option_name: StringName, _options: Dictionary
) -> bool:
	return true


func _get_import_order() -> int:
	return 0


func _get_priority() -> float:
	return 1.0


func _import(
	source_file: String,
	save_path: String,
	_options: Dictionary,
	_platform_variants: Array[String],
	_gen_files: Array[String]
) -> Error:
	var source: WeavlySource = WeavlySource.new()
	source.source_path = source_file
	var out_path: String = "%s.%s" % [save_path, _get_save_extension()]
	return ResourceSaver.save(source, out_path)
