extends WeavlyImageService

const TYPE = "Image"

var image_index: Dictionary[String, String] = {}


func add_image(id: String, path: String) -> void:
	if image_index.has(id):
		push_warning(EXISTING_ID % [TYPE, id])
		return
	image_index[id] = path


func get_image(id: String, default: Texture2D = null) -> Texture2D:
	if not image_index.has(id):
		push_error(MISSING_ID % [TYPE, id, default])
		return default

	var image_path: String = image_index.get(id)
	var texture: Texture2D = load(image_path) as Texture2D

	if texture == null:
		push_error(FAILED_LOADING % [TYPE, image_path, id, default])
		return default

	return texture
