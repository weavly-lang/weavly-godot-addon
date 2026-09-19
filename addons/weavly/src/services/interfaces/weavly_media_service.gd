@abstract class_name WeavlyMediaService
extends WeavlyService

var supported_extensions: PackedStringArray = []

@abstract func set_group_pattern(pattern: String) -> void


func set_supported_extensions(extensions: PackedStringArray) -> void:
	supported_extensions = extensions
