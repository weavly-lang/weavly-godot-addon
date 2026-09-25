extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_character_service.gd"
)

var _service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get
# =====================


func test_add_and_get() -> void:
	var character := WeavlyCharacter.new()
	character.id = "hero"
	_service.add_character(character)
	assert_that(_service.get_character("hero")).is_equal(character)


func test_get_missing_returns_default() -> void:
	assert_that(_service.get_character("missing")).is_null()
	assert_logged(["Character with id 'missing' doesn't exist"])


func test_get_missing_returns_provided_default() -> void:
	var fallback := WeavlyCharacter.new()
	assert_that(_service.get_character("missing", fallback)).is_equal(fallback)
	assert_logged(["Character with id 'missing' doesn't exist"])


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	var first := WeavlyCharacter.new()
	first.id = "hero"
	var second := WeavlyCharacter.new()
	second.id = "hero"
	_service.add_character(first)
	_service.add_character(second)
	assert_logged([], ["Character with id 'hero' already exists."])
	assert_that(_service.get_character("hero")).is_equal(first)
