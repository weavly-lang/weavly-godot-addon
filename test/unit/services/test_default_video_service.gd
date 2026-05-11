extends GutTest

const _Service = preload("res://addons/weavly/src/services/implementations/default_video_service.gd")

# Saved as a .tres (native resource) so no import step is needed in headless/CI runs.
const _FIXTURE_PATH = "res://test/fixtures/test_video.tres"

var _service


func before_each() -> void:
	_service = _Service.new()
	_service.initialize(null)


# =====================
# add / get
# =====================


func test_add_and_get_video() -> void:
	_service.add_video("intro", _FIXTURE_PATH)
	assert_is(_service.get_video("intro"), VideoStream)


func test_get_missing_id_returns_default() -> void:
	assert_null(_service.get_video("missing"))
	assert_push_error(1)


func test_get_missing_id_returns_provided_default() -> void:
	var fallback := VideoStreamTheora.new()
	assert_eq(_service.get_video("missing", fallback), fallback)
	assert_push_error(1)


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	_service.add_video("intro", _FIXTURE_PATH)
	_service.add_video("intro", "res://test/fixtures/other.tres")
	assert_not_null(_service.get_video("intro"))


# =====================
# failed load
# =====================


func test_failed_load_returns_default() -> void:
	_service.add_video("broken", "res://test/fixtures/nonexistent.ogv")
	assert_null(_service.get_video("broken"))
	assert_push_error(1)
