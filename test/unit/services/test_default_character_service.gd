extends GutTest

const _Service = preload("res://addons/weavly/src/services/implementations/default_character_service.gd")

var _service


func before_each() -> void:
	_service = _Service.new()
	_service.initialize(null)


# =====================
# add / get
# =====================


func test_add_and_get() -> void:
	var character := WeavlyCharacter.new()
	character.id = &"hero"
	_service.add_character(character)
	assert_eq(_service.get_character(&"hero"), character)


func test_get_missing_returns_default() -> void:
	assert_null(_service.get_character(&"missing"))
	assert_push_error(1)


func test_get_missing_returns_provided_default() -> void:
	var fallback := WeavlyCharacter.new()
	assert_eq(_service.get_character(&"missing", fallback), fallback)
	assert_push_error(1)


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	var first := WeavlyCharacter.new()
	first.id = &"hero"
	var second := WeavlyCharacter.new()
	second.id = &"hero"
	_service.add_character(first)
	_service.add_character(second)
	assert_engine_error(1)
	assert_eq(_service.get_character(&"hero"), first)
