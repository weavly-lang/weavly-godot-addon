extends WeavlyImageService

const TYPE = "Image"

var image_index: WeavlyMediaIndex = WeavlyMediaIndex.new(TYPE)


func set_group_pattern(pattern: String) -> void:
	image_index.set_group_pattern(pattern)


func add_image(id: String, path: String) -> void:
	image_index.add(id, path)


func get_image(id: String, default: Texture2D = null) -> Texture2D:
	var image_path: String = image_index.pick(id)
	if image_path == "":
		push_error(MISSING_ID % [TYPE, id, default])
		return default

	var texture: Texture2D = load(image_path) as Texture2D
	if texture == null:
		push_error(FAILED_LOADING % [TYPE, image_path, id, default])
		return default

	return texture
