extends WeavlyTestSuite

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
	var engine: WeavlyEngine = auto_free(FakeEngine.new())
	add_child(engine)
	return engine


# =====================
# find_all_files_with_extension
# =====================


func test_find_returns_files_with_matching_extension() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	assert_array(results).is_not_empty()
	for path: String in results:
		assert_str(path).ends_with(".json")


func test_find_ignores_non_matching_extension() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	assert_array(results).not_contains([FIXTURE_DIR + "/not_json.txt"])


func test_find_recurses_into_subdirectories() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	assert_array(results).contains([FIXTURE_DIR + "/sub/nested.json"])


func test_find_skips_dot_files() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".json")
	assert_array(results).not_contains([FIXTURE_DIR + "/.hidden.json"])


func test_find_returns_empty_for_missing_directory() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(
		"res://test/fixtures/does_not_exist", ".json"
	)
	assert_array(results).is_empty()
	assert_logged(["Failed to open directory: res://test/fixtures/does_not_exist"])


func test_find_returns_empty_when_no_matching_extension() -> void:
	var results = WeavlyFileUtils.find_all_files_with_extension(FIXTURE_DIR, ".xyz")
	assert_array(results).is_empty()


# =====================
# load_json_file
# =====================


func test_load_json_returns_parsed_dictionary() -> void:
	var data = WeavlyFileUtils.load_json_file(PLAIN_PATH)
	assert_that(data).is_equal({"hello": "world", "count": 3.0})


func test_load_json_returns_null_on_invalid_json() -> void:
	assert_that(WeavlyFileUtils.load_json_file(INVALID_PATH)).is_null()
	assert_logged(["JSON parse error in res://test/fixtures/file_utils/invalid.json at line 0"])


func test_load_json_returns_null_on_missing_file() -> void:
	assert_that(WeavlyFileUtils.load_json_file(MISSING_PATH)).is_null()
	assert_logged(["Could not open res://test/fixtures/file_utils/does_not_exist.json"])


# =====================
# create_service
# =====================


func test_create_service_returns_user_instance_when_extends_base_type() -> void:
	var engine = _make_engine()
	var service = WeavlyFileUtils.create_service(
		engine, DefaultNodeService, DefaultNodeService, WeavlyNodeService
	)
	assert_bool(service is DefaultNodeService).is_true()
	assert_that(service.engine).is_equal(engine)


func test_create_service_falls_back_to_default_when_wrong_base_type() -> void:
	var engine = _make_engine()
	var service = WeavlyFileUtils.create_service(
		engine, DefaultVariableService, DefaultNodeService, WeavlyNodeService
	)
	assert_bool(service is DefaultNodeService).is_true()
	assert_bool(service is DefaultVariableService).is_false()
	assert_that(service.engine).is_equal(engine)
	assert_logged([], ["Falling back to default."])


func test_create_service_uses_default_when_user_script_null() -> void:
	var engine = _make_engine()
	var service = WeavlyFileUtils.create_service(
		engine, null, DefaultNodeService, WeavlyNodeService
	)
	assert_bool(service is DefaultNodeService).is_true()
	assert_that(service.engine).is_equal(engine)


# =====================
# load_variables_from_resources
# =====================


func test_load_variables_from_resources_loads_number_variable() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, RESOURCES_DIR)
	assert_bool(engine.variable_service.has("score")).is_true()
	assert_that(engine.variable_service.get_variable("score")).is_equal(7.0)


func test_load_variables_from_resources_loads_string_variable() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, RESOURCES_DIR)
	assert_bool(engine.variable_service.has("player_name")).is_true()
	assert_that(engine.variable_service.get_variable("player_name")).is_equal("Ada")


func test_load_variables_from_resources_loads_flag_variable() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, RESOURCES_DIR)
	assert_bool(engine.variable_service.has("door_open")).is_true()
	assert_that(engine.variable_service.get_variable("door_open")).is_equal(true)


# =====================
# load_nodes_from_files / load_variables_from_env_files — malformed input (issue #38)
# =====================


func _make_engine_with_node_service() -> WeavlyEngine:
	var engine = _make_engine()
	engine.node_service = DefaultNodeService.new()
	engine.node_service.initialize(engine)
	return engine


func test_load_nodes_skips_malformed_files_without_crashing() -> void:
	# FIXTURE_DIR mixes an unparseable file, an array-root file, and dictionaries
	# without a "nodes" key alongside valid_nodes.json. A single bad file must
	# not crash startup — the valid node should still load.
	var engine = _make_engine_with_node_service()
	WeavlyFileUtils.load_nodes_from_files(engine, FIXTURE_DIR)
	assert_bool(engine.node_service.has("start")).is_true()
	assert_logged(["JSON parse error in res://test/fixtures/file_utils/invalid.json at line 0"])


func test_load_variables_from_env_skips_malformed_files_without_crashing() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_env_files(engine, FIXTURE_DIR)
	assert_bool(engine.variable_service.has("score")).is_true()
	assert_logged(["JSON parse error in res://test/fixtures/file_utils/invalid.json at line 0"])
