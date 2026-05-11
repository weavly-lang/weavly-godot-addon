extends WeavlyVideoService

const TYPE = "Video"

var video_index: Dictionary[String, Array] = {}
var trailing_index_length: int = 4


func add_video(id: String, path: String) -> void:
	var id_group = id.substr(0, max(id.length() - trailing_index_length, 0))
	var paths: Array = video_index.get(id_group, [])
	paths.append(path)
	video_index[id_group] = paths


func get_video(id_group: String, default: VideoStream = null) -> VideoStream:
	if not video_index.has(id_group):
		push_error(MISSING_ID % [TYPE, id_group, default])
		return default

	var video_paths: Array = video_index.get(id_group)
	var video_path: String = video_paths.pick_random()
	var video_stream: VideoStream = load(video_path) as VideoStream

	if video_stream == null:
		push_error(FAILED_LOADING % [TYPE, video_path, id_group, default])
		return default

	return video_stream
