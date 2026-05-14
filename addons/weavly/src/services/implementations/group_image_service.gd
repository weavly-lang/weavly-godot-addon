extends WeavlyImageService

const TYPE = "Image"

var image_index: Dictionary[String, Array] = {}
var trailing_index_length: int = 4


func add_image(id: String, path: String) -> void:
	var id_group = id.substr(0, max(id.length() - trailing_index_length, 0))
	var paths: Array = image_index.get(id_group, [])
	paths.append(path)
	image_index[id_group] = paths


func get_image(id_group: String, default: Texture2D = null) -> Texture2D:
	if not image_index.has(id_group):
		push_error(MISSING_ID % [TYPE, id_group, default])
		return default

	var image_paths: Array = image_index.get(id_group)
	var image_path: String = image_paths.pick_random()
	var texture: Texture2D = load(image_path) as Texture2D

	if texture == null:
		push_error(FAILED_LOADING % [TYPE, image_path, id_group, default])
		return default

	return texture
