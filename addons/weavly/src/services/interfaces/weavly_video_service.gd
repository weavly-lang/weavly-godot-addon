@abstract class_name WeavlyVideoService
extends WeavlyMediaService

@abstract func get_video(id: String, default: VideoStream = null) -> VideoStream

@abstract func add_video(id: String, path: String) -> void


func _init() -> void:
	supported_extensions = [".ogv"]
