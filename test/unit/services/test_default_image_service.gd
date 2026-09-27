extends WeavlyTestSuite

# Only what the image service adds to WeavlyMediaIndex; grouping and duplicates are tested there.

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_image_service.gd"
)

# Saved as a .tres (native resource) so no import step is needed in headless/CI runs.
const _FIXTURE_PATH = "res://test/fixtures/test_image.tres"

var _service: Service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


func test_add_and_get_image() -> void:
	_service.add_media("splash", _FIXTURE_PATH)
	assert_object(_service.get_image("splash")).is_instanceof(Texture2D)


func test_get_missing_id_returns_provided_default() -> void:
	var fallback: ImageTexture = ImageTexture.new()
	assert_that(_service.get_image("missing", fallback)).is_equal(fallback)
	assert_logged(["Image with id 'missing' doesn't exist"])


func test_failed_load_returns_default() -> void:
	_service.add_media("broken", "res://test/fixtures/nonexistent.png")
	assert_that(_service.get_image("broken")).is_null()
	assert_logged(
		[
			"Method/function failed. Returning: Ref<Resource>()",
			"Failed to load Image at path 'res://test/fixtures/nonexistent.png' for id 'broken'"
		]
	)


func test_the_group_pattern_groups_images() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_media("cat_1", _FIXTURE_PATH)
	_service.add_media("cat_2", _FIXTURE_PATH)
	assert_object(_service.get_image("cat")).is_instanceof(Texture2D)


# =====================
# External paths (issue #57)
# =====================


func test_get_image_loads_a_file_outside_res() -> void:
	var path: String = create_temp_dir("image_external").path_join("splash.png")
	Image.create(2, 2, false, Image.FORMAT_RGB8).save_png(path)
	_service.add_media("splash", path)
	assert_object(_service.get_image("splash")).is_instanceof(Texture2D)


func test_get_image_returns_default_for_a_missing_external_file() -> void:
	var path: String = create_temp_dir("image_external_missing").path_join("nope.png")
	_service.add_media("broken", path)
	assert_that(_service.get_image("broken")).is_null()
	assert_logged(["Failed to load Image at path"])
