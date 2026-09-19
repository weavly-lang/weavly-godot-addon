class_name WeavlyMediaIndex
extends RefCounted

const INVALID_PATTERN = "Failed to compile %s group_pattern '%s', falling back to no grouping."

var paths: Dictionary[String, Array] = {}

var _type: String
var _regex: RegEx = null


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


func add(id: String, path: String) -> void:
	if _regex == null:
		if paths.has(id):
			push_warning(WeavlyService.EXISTING_ID % [_type, id])
			return
		paths[id] = [path]
		return

	var group_key: String = id
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
