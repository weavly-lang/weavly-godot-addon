class_name WeavlyDefaultImageService
extends WeavlyImageService

const TYPE = "Image"

var image_index: WeavlyMediaIndex = WeavlyMediaIndex.new(TYPE, &"Texture2D")


# Indexes the files in the engine's image_path, grouped by its image_group_pattern.
func initialize(engine: WeavlyEngine) -> void:
	super(engine)
	image_index.index_folder(
		engine.image_path, engine.image_group_pattern, engine.image_extensions
	)


func set_group_pattern(pattern: String) -> void:
	image_index.set_group_pattern(pattern)


func add_media(id: String, path: String) -> void:
	image_index.add(id, path)


func get_image(id: String) -> Texture2D:
	return image_index.load_media(id, _read_file)


static func _read_file(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null else null
