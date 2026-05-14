extends GutTest

const Service = preload("res://addons/weavly/src/services/implementations/group_video_service.gd")

const _FIXTURE_PATH = "res://test/fixtures/test_video.tres"

var _service


func before_each() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add_video / grouping
# =====================


func test_add_video_groups_by_prefix() -> void:
	_service.add_video("intro0001", _FIXTURE_PATH)
	_service.add_video("intro0002", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)


func test_ids_with_different_prefixes_are_separate_groups() -> void:
	_service.add_video("alpha0001", _FIXTURE_PATH)
	assert_null(_service.get_video("beta"))
	assert_push_error(1)


# =====================
# get_video
# =====================


func test_get_video_returns_video_stream() -> void:
	_service.add_video("intro0001", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)


func test_get_missing_group_returns_default() -> void:
	assert_null(_service.get_video("missing"))
	assert_push_error(1)


func test_get_missing_group_returns_provided_default() -> void:
	var fallback := VideoStreamTheora.new()
	assert_eq(_service.get_video("missing", fallback), fallback)
	assert_push_error(1)


# =====================
# failed load
# =====================


func test_failed_load_returns_default() -> void:
	_service.add_video("broken0001", "res://test/fixtures/nonexistent.ogv")
	assert_null(_service.get_video("broken"))
	assert_engine_error(1)
	assert_push_error(1)
