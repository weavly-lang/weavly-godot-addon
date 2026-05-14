extends GutTest

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_image_service.gd"
)

# Saved as a .tres (native resource) so no import step is needed in headless/CI runs.
const _FIXTURE_PATH = "res://test/fixtures/test_image.tres"

var _service


func before_each() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get (no pattern)
# =====================


func test_add_and_get_image() -> void:
	_service.add_image("splash", _FIXTURE_PATH)
	assert_is(_service.get_image("splash"), Texture2D)


func test_get_missing_id_returns_default() -> void:
	assert_null(_service.get_image("missing"))
	assert_push_error(1)


func test_get_missing_id_returns_provided_default() -> void:
	var fallback: ImageTexture = ImageTexture.new()
	assert_eq(_service.get_image("missing", fallback), fallback)
	assert_push_error(1)


# =====================
# duplicate id (no pattern)
# =====================


func test_add_duplicate_is_ignored() -> void:
	_service.add_image("splash", _FIXTURE_PATH)
	_service.add_image("splash", "res://test/fixtures/other.tres")
	assert_engine_error(1)
	assert_not_null(_service.get_image("splash"))


# =====================
# failed load
# =====================


func test_failed_load_returns_default() -> void:
	_service.add_image("broken", "res://test/fixtures/nonexistent.png")
	assert_null(_service.get_image("broken"))
	assert_engine_error(1)
	assert_push_error(1)


# =====================
# grouping (pattern set)
# =====================


func test_grouping_strips_suffix() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("cat_1", _FIXTURE_PATH)
	_service.add_image("cat_2", _FIXTURE_PATH)
	assert_is(_service.get_image("cat"), Texture2D)


func test_unmatched_id_is_singleton_with_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("logo", _FIXTURE_PATH)
	assert_is(_service.get_image("logo"), Texture2D)


func test_grouped_and_ungrouped_coexist() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("cat_1", _FIXTURE_PATH)
	_service.add_image("logo", _FIXTURE_PATH)
	assert_is(_service.get_image("cat"), Texture2D)
	assert_is(_service.get_image("logo"), Texture2D)


func test_duplicates_allowed_when_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_image("cat_1", _FIXTURE_PATH)
	_service.add_image("cat_1", _FIXTURE_PATH)
	assert_no_new_warnings()
	assert_is(_service.get_image("cat"), Texture2D)


# =====================
# invalid pattern
# =====================


func test_invalid_pattern_falls_back_to_no_grouping() -> void:
	_service.set_group_pattern("[")
	assert_push_error(1)
	_service.add_image("splash", _FIXTURE_PATH)
	assert_is(_service.get_image("splash"), Texture2D)


func test_invalid_pattern_duplicate_still_warns() -> void:
	_service.set_group_pattern("[")
	assert_push_error(1)
	_service.add_image("splash", _FIXTURE_PATH)
	_service.add_image("splash", "res://test/fixtures/other.tres")
	assert_engine_error(1)
