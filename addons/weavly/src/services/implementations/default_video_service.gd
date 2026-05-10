extends WeavlyVideoService

const TYPE = "Video"

var video_index: Dictionary[String, String] = {}


func add_video(id: String, path: String) -> void:
	if video_index.has(id):
		push_warning(EXISTING_ID % [TYPE, id])
		return
	video_index[id] = path


func get_video(id: String, default: VideoStream = null) -> VideoStream:
	if not video_index.has(id):
		push_error(MISSING_ID % [TYPE, id, default])
		return default
	
	var video_path: String = video_index.get(id)
	var video_stream: VideoStream = load(video_path) as VideoStream
	
	if video_stream == null:
		push_error(FAILED_LOADING % [TYPE, video_path, id, default])
		return default
		
	return video_stream
