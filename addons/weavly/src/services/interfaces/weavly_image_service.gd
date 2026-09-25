@abstract class_name WeavlyImageService
extends WeavlyMediaService

@abstract func get_image(id: String, default: Texture2D = null) -> Texture2D


func _init() -> void:
	supported_extensions = [".png", ".jpg"]
