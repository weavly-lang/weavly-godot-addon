extends WeavlyImageService

const TYPE = "Image"

var image_index: WeavlyMediaIndex = WeavlyMediaIndex.new(TYPE)


func set_group_pattern(pattern: String) -> void:
	image_index.set_group_pattern(pattern)


func add_media(id: String, path: String) -> void:
	image_index.add(id, path)


func get_image(id: String, default: Texture2D = null) -> Texture2D:
	return image_index.load_media(id, default, _load_texture)


# Paths outside res:// are not in the resource system, so they are read straight
# from disk (see #57).
func _load_texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		return load(path) as Texture2D

	if not FileAccess.file_exists(path):
		return null
	var image: Image = Image.load_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)
