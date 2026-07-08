extends GutTest

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_video_service.gd"
)

# Saved as a .tres (native resource) so no import step is needed in headless/CI runs.
const _FIXTURE_PATH = "res://test/fixtures/test_video.tres"

var _service


func before_each() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get (no pattern)
# =====================


func test_add_and_get_video() -> void:
	_service.add_video("intro", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)


func test_get_missing_id_returns_default() -> void:
	assert_null(_service.get_video("missing"))
	assert_push_error(1)


func test_get_missing_id_returns_provided_default() -> void:
	var fallback: VideoStreamTheora = VideoStreamTheora.new()
	assert_eq(_service.get_video("missing", fallback), fallback)
	assert_push_error(1)


# =====================
# duplicate id (no pattern)
# =====================


func test_add_duplicate_is_ignored() -> void:
	_service.add_video("intro", _FIXTURE_PATH)
	_service.add_video("intro", "res://test/fixtures/other.tres")
	assert_engine_error(1)
	assert_not_null(_service.get_video("intro"))


# =====================
# failed load
# =====================


func test_failed_load_returns_default() -> void:
	_service.add_video("broken", "res://test/fixtures/nonexistent.ogv")
	assert_null(_service.get_video("broken"))
	assert_engine_error(1)
	assert_push_error(1)


# =====================
# grouping (pattern set)
# =====================


func test_grouping_strips_suffix() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_video("intro_1", _FIXTURE_PATH)
	_service.add_video("intro_2", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)


func test_grouping_strips_mid_string_match() -> void:
	_service.set_group_pattern("_v\\d+")
	_service.add_video("intro_v1_wide", _FIXTURE_PATH)
	_service.add_video("intro_v2_wide", _FIXTURE_PATH)
	assert_is(_service.get_video("intro_wide"), VideoStream)


func test_unmatched_id_is_singleton_with_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_video("title", _FIXTURE_PATH)
	assert_is(_service.get_video("title"), VideoStream)


func test_grouped_and_ungrouped_coexist() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_video("intro_1", _FIXTURE_PATH)
	_service.add_video("title", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)
	assert_is(_service.get_video("title"), VideoStream)


func test_duplicates_allowed_when_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_video("intro_1", _FIXTURE_PATH)
	_service.add_video("intro_1", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)


# =====================
# invalid pattern
# =====================


func test_invalid_pattern_falls_back_to_no_grouping() -> void:
	_service.set_group_pattern("[")
	assert_push_error(1)
	assert_engine_error(1)
	_service.add_video("intro", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)


func test_invalid_pattern_duplicate_still_warns() -> void:
	_service.set_group_pattern("[")
	assert_push_error(1)
	_service.add_video("intro", _FIXTURE_PATH)
	_service.add_video("intro", "res://test/fixtures/other.tres")
	assert_engine_error(2)
