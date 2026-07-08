extends GutTest

const FakeEngine = preload("res://test/helpers/fake_engine.gd")
const DefaultNodeService = preload(
	"res://addons/weavly/src/services/implementations/default_node_service.gd"
)
const DefaultVariableService = preload(
	"res://addons/weavly/src/services/implementations/default_variable_service.gd"
)

const FIXTURE_DIR = "res://test/fixtures/file_utils"
const RESOURCES_DIR = FIXTURE_DIR + "/resources"
const PLAIN_PATH = FIXTURE_DIR + "/plain.json"
const INVALID_PATH = FIXTURE_DIR + "/invalid.json"
const MISSING_PATH = FIXTURE_DIR + "/does_not_exist.json"


func _make_engine() -> WeavlyEngine:
	return add_child_autofree(FakeEngine.new())


# =====================
# find_all_files_with_extension
# =====================


func test_find_returns_files_with_matching_extension() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	for path in results:
		assert_true(path.ends_with(".json"), "expected only .json paths, got: " + path)
	assert_true(results.size() > 0, "expected at least one .json file")


func test_find_ignores_non_matching_extension() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	for path in results:
		assert_false(path.ends_with(".txt"), "unexpected .txt path: " + path)


func test_find_recurses_into_subdirectories() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	var found_nested := false
	for path in results:
		if path.ends_with("sub/nested.json"):
			found_nested = true
			break
	assert_true(found_nested, "expected to find sub/nested.json, got: " + str(results))


func test_find_skips_dot_files() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	for path in results:
		assert_false(path.get_file().begins_with("."), "unexpected dot-file in results: " + path)


func test_find_returns_empty_for_missing_directory() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(
		"res://test/fixtures/does_not_exist", ".json"
	)
	assert_eq(results.size(), 0)
	assert_push_error(1)


func test_find_returns_empty_when_no_matching_extension() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".xyz")
	assert_eq(results.size(), 0)


# =====================
# load_json_file
# =====================


func test_load_json_returns_parsed_dictionary() -> void:
	var data = WeavlyFileUtils.load_json_file(PLAIN_PATH)
	assert_eq(data, {"hello": "world", "count": 3.0})


func test_load_json_returns_null_on_invalid_json() -> void:
	assert_null(WeavlyFileUtils.load_json_file(INVALID_PATH))
	assert_push_error(1)


func test_load_json_returns_null_on_missing_file() -> void:
	assert_null(WeavlyFileUtils.load_json_file(MISSING_PATH))
	assert_push_error(1)


# =====================
# create_service
# =====================


func test_create_service_returns_user_instance_when_extends_base_type() -> void:
	var engine = _make_engine()
	var service = WeavlyFileUtils.create_service(
		engine, DefaultNodeService, DefaultNodeService, WeavlyNodeService
	)
	assert_true(service is DefaultNodeService)
	assert_eq(service.engine, engine)


func test_create_service_falls_back_to_default_when_wrong_base_type() -> void:
	var engine = _make_engine()
	var service = WeavlyFileUtils.create_service(
		engine, DefaultVariableService, DefaultNodeService, WeavlyNodeService
	)
	assert_true(service is DefaultNodeService)
	assert_false(service is DefaultVariableService)
	assert_eq(service.engine, engine)
	assert_engine_error(1)


func test_create_service_uses_default_when_user_script_null() -> void:
	var engine = _make_engine()
	var service = WeavlyFileUtils.create_service(
		engine, null, DefaultNodeService, WeavlyNodeService
	)
	assert_true(service is DefaultNodeService)
	assert_eq(service.engine, engine)


# =====================
# load_variables_from_resources
# =====================


func test_load_variables_from_resources_loads_number_variable() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, RESOURCES_DIR)
	assert_true(engine.variable_service.has("score"), "expected number variable to be added")
	assert_eq(engine.variable_service.get_variable("score"), 7.0)


func test_load_variables_from_resources_loads_string_variable() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, RESOURCES_DIR)
	assert_true(engine.variable_service.has("player_name"), "expected string variable to be added")
	assert_eq(engine.variable_service.get_variable("player_name"), "Ada")


func test_load_variables_from_resources_loads_flag_variable() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, RESOURCES_DIR)
	assert_true(engine.variable_service.has("door_open"), "expected flag variable to be added")
	assert_eq(engine.variable_service.get_variable("door_open"), true)
