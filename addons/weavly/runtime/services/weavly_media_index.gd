class_name WeavlyMediaIndex
extends RefCounted

const INVALID_PATTERN = "Failed to compile %s group_pattern '%s', falling back to no grouping."
const DUPLICATE_ID = "%s id '%s' is used by both %s and %s, using %s."

var paths: Dictionary[String, Array] = {}

var _type: String
var _resource_class: StringName
var _regex: RegEx = null
var _sources: Dictionary[String, String] = {}


# resource_class is the class a res:// file must load as.
func _init(type: String, resource_class: StringName) -> void:
	_type = type
	_resource_class = resource_class


# An empty dir adds no files.
func index_folder(dir: String, group_pattern: String, extensions: PackedStringArray) -> void:
	set_group_pattern(group_pattern)
	if not dir.is_empty():
		WeavlyFileUtils.index_media(self, dir, extensions)


func set_group_pattern(pattern: String) -> void:
	if pattern == "":
		_regex = null
		return
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		push_error(INVALID_PATTERN % [_type.to_lower(), pattern])
		_regex = null
		return
	_regex = regex


# Ids are checked before grouping, so only files whose ids differ form a group.
func add(id: String, path: String) -> void:
	if _sources.has(id):
		push_error(DUPLICATE_ID % [_type, id, _sources[id], path, _sources[id]])
		return
	_sources[id] = path

	var group_key: String = _group_key(id)
	var group: Array = paths.get(group_key, [])
	group.append(path)
	paths[group_key] = group


# The pattern only applies to the file name, so files in different folders never share a group.
func _group_key(id: String) -> String:
	if _regex == null:
		return id
	var name: String = id.get_file()
	var found: RegExMatch = _regex.search(name)
	if not found:
		return id
	var grouped: String = name.substr(0, found.get_start()) + name.substr(found.get_end())
	var folder: String = id.get_base_dir()
	return folder.path_join(grouped) if folder != "" else grouped


# Empty when the id is unknown; a group returns one of its paths at random.
func pick(id: String) -> String:
	if not paths.has(id):
		return ""
	return paths[id].pick_random()


# Loads a picked path, or returns null on failure. Paths outside res:// aren't in the resource
# system, so read_file reads them from disk and returns null on failure (see #57).
func load_media(id: String, read_file: Callable) -> Variant:
	var path: String = pick(id)
	if path == "":
		push_error(WeavlyService.MISSING_ID % [_type, id])
		return null
	var media: Variant = _load(path, read_file)
	if media == null:
		push_error(WeavlyService.FAILED_LOADING % [_type, path, id])
	return media


func _load(path: String, read_file: Callable) -> Variant:
	if path.begins_with("res://"):
		var resource: Resource = load(path)
		return resource if resource != null and resource.is_class(_resource_class) else null
	if not FileAccess.file_exists(path):
		return null
	return read_file.call(path)
