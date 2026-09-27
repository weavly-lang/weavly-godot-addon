@abstract class_name WeavlyMediaService
extends WeavlyService

var supported_extensions: PackedStringArray = []

@abstract func set_group_pattern(pattern: String) -> void

@abstract func add_media(id: String, path: String) -> void


func set_supported_extensions(extensions: PackedStringArray) -> void:
	supported_extensions = extensions
