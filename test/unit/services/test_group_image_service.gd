extends GutTest

const Service = preload("res://addons/weavly/src/services/implementations/group_image_service.gd")

const _FIXTURE_PATH = "res://test/fixtures/test_image.tres"

var _service


func before_each() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add_image / grouping
# =====================


func test_add_image_groups_by_prefix() -> void:
	_service.add_image("splash0001", _FIXTURE_PATH)
	_service.add_image("splash0002", _FIXTURE_PATH)
	assert_is(_service.get_image("splash"), Texture2D)


func test_ids_with_different_prefixes_are_separate_groups() -> void:
	_service.add_image("alpha0001", _FIXTURE_PATH)
	assert_null(_service.get_image("beta"))
	assert_push_error(1)


# =====================
# get_image
# =====================


func test_get_image_returns_texture() -> void:
	_service.add_image("splash0001", _FIXTURE_PATH)
	assert_is(_service.get_image("splash"), Texture2D)


func test_get_missing_group_returns_default() -> void:
	assert_null(_service.get_image("missing"))
	assert_push_error(1)


func test_get_missing_group_returns_provided_default() -> void:
	var fallback := ImageTexture.new()
	assert_eq(_service.get_image("missing", fallback), fallback)
	assert_push_error(1)


# =====================
# failed load
# =====================


func test_failed_load_returns_default() -> void:
	_service.add_image("broken0001", "res://test/fixtures/nonexistent.png")
	assert_null(_service.get_image("broken"))
	assert_engine_error(1)
	assert_push_error(1)
