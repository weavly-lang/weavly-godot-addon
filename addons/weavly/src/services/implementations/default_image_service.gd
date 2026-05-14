extends WeavlyImageService

const TYPE = "Image"

var image_index: Dictionary[String, Array] = {}
var _regex: RegEx = null


func set_group_pattern(pattern: String) -> void:
	if pattern == "":
		_regex = null
		return
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		push_error(
			"Failed to compile image group_pattern '%s', falling back to no grouping." % pattern
		)
		_regex = null
		return
	_regex = regex


func add_image(id: String, path: String) -> void:
	if _regex == null:
		if image_index.has(id):
			push_warning(EXISTING_ID % [TYPE, id])
			return
		image_index[id] = [path]
		return

	var group_key: String = id
	var match: RegExMatch = _regex.search(id)
	if match:
		group_key = id.substr(0, id.length() - match.get_string().length())

	var paths: Array = image_index.get(group_key, [])
	paths.append(path)
	image_index[group_key] = paths


func get_image(id: String, default: Texture2D = null) -> Texture2D:
	if not image_index.has(id):
		push_error(MISSING_ID % [TYPE, id, default])
		return default

	var image_paths: Array = image_index.get(id)
	var image_path: String = image_paths.pick_random()
	var texture: Texture2D = load(image_path) as Texture2D

	if texture == null:
		push_error(FAILED_LOADING % [TYPE, image_path, id, default])
		return default

	return texture
