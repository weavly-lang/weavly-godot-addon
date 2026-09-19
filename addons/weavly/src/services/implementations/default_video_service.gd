extends WeavlyVideoService

const TYPE = "Video"

var video_index: WeavlyMediaIndex = WeavlyMediaIndex.new(TYPE)


func set_group_pattern(pattern: String) -> void:
	video_index.set_group_pattern(pattern)


func add_video(id: String, path: String) -> void:
	video_index.add(id, path)


func get_video(id: String, default: VideoStream = null) -> VideoStream:
	var video_path: String = video_index.pick(id)
	if video_path == "":
		push_error(MISSING_ID % [TYPE, id, default])
		return default

	var video_stream: VideoStream = load(video_path) as VideoStream
	if video_stream == null:
		push_error(FAILED_LOADING % [TYPE, video_path, id, default])
		return default

	return video_stream
