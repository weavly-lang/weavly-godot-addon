extends WeavlyVideoService

const TYPE = "Video"

var video_index: WeavlyMediaIndex = WeavlyMediaIndex.new(TYPE)


func set_group_pattern(pattern: String) -> void:
	video_index.set_group_pattern(pattern)


func add_media(id: String, path: String) -> void:
	video_index.add(id, path)


func get_video(id: String, default: VideoStream = null) -> VideoStream:
	return video_index.load_media(id, default, _load_video)


# Paths outside res:// are not in the resource system, so the stream reads the
# file straight from disk (see #57).
func _load_video(path: String) -> VideoStream:
	if path.begins_with("res://"):
		return load(path) as VideoStream

	if not FileAccess.file_exists(path):
		return null
	var stream: VideoStreamTheora = VideoStreamTheora.new()
	stream.file = path
	return stream
