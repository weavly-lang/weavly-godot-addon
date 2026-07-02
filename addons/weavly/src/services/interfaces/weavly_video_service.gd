@abstract class_name WeavlyVideoService
extends WeavlyService

var supported_extensions: PackedStringArray = [".ogv"]

@abstract func get_video(id: String, default: VideoStream = null) -> VideoStream

@abstract func add_video(id: String, path: String) -> void

@abstract func set_group_pattern(pattern: String) -> void


func set_supported_extensions(extensions: PackedStringArray) -> void:
	supported_extensions = extensions
