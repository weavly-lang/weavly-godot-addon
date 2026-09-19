extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_image_service.gd"
)

# Saved as a .tres (native resource) so no import step is needed in headless/CI runs.
const _FIXTURE_PATH = "res://test/fixtures/test_image.tres"

var _service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get (no pattern)
# =====================


func test_add_and_get_image() -> void:
	_service.add_image("splash", _FIXTURE_PATH)
	assert_object(_service.get_image("splash")).is_instanceof(Texture2D)


func test_get_missing_id_returns_default() -> void:
	assert_that(_service.get_image("missing")).is_null()
	assert_logged(["Image with id 'missing' doesn't exist"])


func test_get_missing_id_returns_provided_default() -> void:
	var fallback: ImageTexture = ImageTexture.new()
	assert_that(_service.get_image("missing", fallback)).is_equal(fallback)
	assert_logged(["Image with id 'missing' doesn't exist"])


# =====================
# duplicate id (no pattern)
# =====================


func test_add_duplicate_is_ignored() -> void:
	_service.add_image("splash", _FIXTURE_PATH)
	_service.add_image("splash", "res://test/fixtures/other.tres")
	assert_logged([], ["Image with id 'splash' already exists."])
	assert_that(_service.get_image("splash")).is_not_null()


# =====================
# failed load
# =====================


func test_failed_load_returns_default() -> void:
	_service.add_image("broken", "res://test/fixtures/nonexistent.png")
	assert_that(_service.get_image("broken")).is_null()
	assert_logged(
		[
			"Method/function failed. Returning: Ref<Resource>()",
			"Failed to load Image at path 'res://test/fixtures/nonexistent.png' for id 'broken'"
		]
	)


# =====================
# grouping (pattern set)
# =====================


func test_grouping_strips_suffix() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("cat_1", _FIXTURE_PATH)
	_service.add_image("cat_2", _FIXTURE_PATH)
	assert_object(_service.get_image("cat")).is_instanceof(Texture2D)


func test_grouping_strips_mid_string_match() -> void:
	_service.set_group_pattern("_v\\d+")
	_service.add_image("hero_v1_idle", _FIXTURE_PATH)
	_service.add_image("hero_v2_idle", _FIXTURE_PATH)
	assert_object(_service.get_image("hero_idle")).is_instanceof(Texture2D)


func test_unmatched_id_is_singleton_with_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("logo", _FIXTURE_PATH)
	assert_object(_service.get_image("logo")).is_instanceof(Texture2D)


func test_grouped_and_ungrouped_coexist() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("cat_1", _FIXTURE_PATH)
	_service.add_image("logo", _FIXTURE_PATH)
	assert_object(_service.get_image("cat")).is_instanceof(Texture2D)
	assert_object(_service.get_image("logo")).is_instanceof(Texture2D)


func test_duplicates_allowed_when_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("cat_1", _FIXTURE_PATH)
	_service.add_image("cat_1", _FIXTURE_PATH)
	assert_object(_service.get_image("cat")).is_instanceof(Texture2D)


# =====================
# invalid pattern
# =====================


func test_invalid_pattern_falls_back_to_no_grouping() -> void:
	_service.set_group_pattern("[")
	assert_logged(
		[
			"1: missing terminating ] for character class",
			"Failed to compile image group_pattern '[', falling back to no grouping."
		]
	)
	_service.add_image("splash", _FIXTURE_PATH)
	assert_object(_service.get_image("splash")).is_instanceof(Texture2D)


func test_invalid_pattern_duplicate_still_warns() -> void:
	_service.set_group_pattern("[")
	assert_logged(
		[
			"1: missing terminating ] for character class",
			"Failed to compile image group_pattern '[', falling back to no grouping."
		]
	)
	_service.add_image("splash", _FIXTURE_PATH)
	_service.add_image("splash", "res://test/fixtures/other.tres")
	assert_logged([], ["Image with id 'splash' already exists."])
