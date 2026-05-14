extends WeavlyVideoService

const TYPE = "Video"

var video_index: Dictionary[String, Array] = {}
var _regex: RegEx = null


func set_group_pattern(pattern: String) -> void:
	if pattern == "":
		_regex = null
		return
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		push_error(
			"Failed to compile video group_pattern '%s', falling back to no grouping." % pattern
		)
		_regex = null
		return
	_regex = regex


func add_video(id: String, path: String) -> void:
	if _regex == null:
		if video_index.has(id):
			push_warning(EXISTING_ID % [TYPE, id])
			return
		video_index[id] = [path]
		return

	var group_key: String = id
	var match: RegExMatch = _regex.search(id)
	if match:
		group_key = id.substr(0, id.length() - match.get_string().length())

	var paths: Array = video_index.get(group_key, [])
	paths.append(path)
	video_index[group_key] = paths


func get_video(id: String, default: VideoStream = null) -> VideoStream:
	if not video_index.has(id):
		push_error(MISSING_ID % [TYPE, id, default])
		return default

	var video_paths: Array = video_index.get(id)
	var video_path: String = video_paths.pick_random()
	var video_stream: VideoStream = load(video_path) as VideoStream

	if video_stream == null:
		push_error(FAILED_LOADING % [TYPE, video_path, id, default])
		return default

	return video_stream
