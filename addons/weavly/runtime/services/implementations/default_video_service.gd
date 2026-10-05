class_name WeavlyDefaultVideoService
extends WeavlyVideoService

const TYPE = "Video"

var video_index: WeavlyMediaIndex = WeavlyMediaIndex.new(TYPE, &"VideoStream")


# Indexes the files in the engine's video_path, grouped by its video_group_pattern.
func initialize(engine: WeavlyEngine) -> void:
	super(engine)
	video_index.index_folder(
		engine.video_path, engine.video_group_pattern, engine.video_extensions
	)


func set_group_pattern(pattern: String) -> void:
	video_index.set_group_pattern(pattern)


func add_media(id: String, path: String) -> void:
	video_index.add(id, path)


func get_video(id: String) -> VideoStream:
	return video_index.load_media(id, _read_file)


static func _read_file(path: String) -> VideoStream:
	var stream: VideoStreamTheora = VideoStreamTheora.new()
	stream.file = path
	return stream
