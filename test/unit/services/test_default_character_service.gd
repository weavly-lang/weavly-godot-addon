extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/runtime/services/implementations/default_character_service.gd"
)
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _service: Service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(auto_free(FakeEngine.new()))


# =====================
# add / get
# =====================


func test_add_and_get() -> void:
	var character: WeavlyCharacter = WeavlyCharacter.new()
	character.id = "hero"
	_service.add_character(character)
	assert_that(_service.get_character("hero")).is_equal(character)


func test_get_missing_returns_null() -> void:
	assert_that(_service.get_character("missing")).is_null()
	assert_logged(["Character with id 'missing' doesn't exist"])


func test_has() -> void:
	var character: WeavlyCharacter = WeavlyCharacter.new()
	character.id = "hero"
	_service.add_character(character)
	assert_bool(_service.has("hero")).is_true()
	assert_bool(_service.has("missing")).is_false()


# =====================
# duplicate id
# =====================


func test_add_duplicate_is_ignored() -> void:
	var first: WeavlyCharacter = WeavlyCharacter.new()
	first.id = "hero"
	var second: WeavlyCharacter = WeavlyCharacter.new()
	second.id = "hero"
	_service.add_character(first)
	_service.add_character(second)
	assert_logged([], ["Character with id 'hero' already exists."])
	assert_that(_service.get_character("hero")).is_equal(first)


# =====================
# get_display_name
# =====================


func test_display_name_comes_from_the_resource() -> void:
	var character: WeavlyCharacter = WeavlyCharacter.new()
	character.id = "Hero"
	character.display_name = "Robin"
	_service.add_character(character)
	assert_str(_service.get_display_name("Hero")).is_equal("Robin")


func test_a_resource_without_a_display_name_shows_the_id() -> void:
	var character: WeavlyCharacter = WeavlyCharacter.new()
	character.id = "Hero"
	_service.add_character(character)
	assert_str(_service.get_display_name("Hero")).is_equal("Hero")


func test_a_character_without_a_resource_shows_its_id() -> void:
	assert_str(_service.get_display_name("Hero")).is_equal("Hero")
	assert_int(_warnings_about("Hero")).is_equal(0)


func test_a_missing_resource_is_reported_once_when_the_game_has_characters() -> void:
	_service.engine.character_path = "res://characters"
	assert_str(_service.get_display_name("Hero")).is_equal("Hero")
	assert_str(_service.get_display_name("Hero")).is_equal("Hero")
	assert_int(_warnings_about("Character 'Hero' has no WeavlyCharacter resource")).is_equal(1)
	assert_logged([], ["Character 'Hero' has no WeavlyCharacter resource, showing its id."])


func _warnings_about(text: String) -> int:
	var monitor: GodotGdErrorMonitor = (
		GdUnitThreadManager.get_current_context().get_execution_context().error_monitor
	)
	var count: int = 0
	for entry: ErrorLogEntry in monitor.log_entries():
		if entry._type == ErrorLogEntry.TYPE.PUSH_WARNING and entry._message.contains(text):
			count += 1
	return count
