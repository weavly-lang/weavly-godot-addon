class_name WeavlyMediaIndex
extends RefCounted

const INVALID_PATTERN = "Failed to compile %s group_pattern '%s', falling back to no grouping."
const DUPLICATE_ID = "%s id '%s' is used by both %s and %s, using %s."

var paths: Dictionary[String, Array] = {}

var _type: String
var _regex: RegEx = null
var _sources: Dictionary[String, String] = {}


func _init(type: String) -> void:
	_type = type


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

	var group_key: String = id
	if _regex != null:
		var found: RegExMatch = _regex.search(id)
		if found:
			group_key = id.substr(0, found.get_start()) + id.substr(found.get_end())

	var group: Array = paths.get(group_key, [])
	group.append(path)
	paths[group_key] = group


# Empty when the id is unknown; a group returns one of its paths at random.
func pick(id: String) -> String:
	if not paths.has(id):
		return ""
	return paths[id].pick_random()
