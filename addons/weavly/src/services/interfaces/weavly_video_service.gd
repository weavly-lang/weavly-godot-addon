@abstract class_name WeavlyVideoService
extends WeavlyService

@abstract func get_video(id: String, default: VideoStream = null) -> VideoStream

@abstract func add_video(id: String, path: String) -> void

@abstract func set_group_pattern(pattern: String) -> void
