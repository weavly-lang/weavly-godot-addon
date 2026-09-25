@abstract class_name WeavlyVideoService
extends WeavlyMediaService

@abstract func get_video(id: String, default: VideoStream = null) -> VideoStream


func _init() -> void:
	supported_extensions = [".ogv"]
