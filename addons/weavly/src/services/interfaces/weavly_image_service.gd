@abstract class_name WeavlyImageService
extends WeavlyService

var supported_extensions: PackedStringArray = [".png", ".jpg"]

@abstract func get_image(id: String, default: Texture2D = null) -> Texture2D

@abstract func add_image(id: String, path: String) -> void

@abstract func set_group_pattern(pattern: String) -> void


func set_supported_extensions(extensions: PackedStringArray) -> void:
	supported_extensions = extensions
