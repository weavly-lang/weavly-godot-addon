# gdlint:ignore = max-public-methods
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
const VARIABLES_DIR = "res://test/fixtures/variables"


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


# =====================
# External directories (issue #57)
# =====================


func test_find_lists_files_outside_res() -> void:
	var dir: String = create_temp_dir("find_external")
	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.save_png(dir.path_join("a.png"))
	image.save_png(dir.path_join("b.txt"))
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(dir, ".png")
	assert_array(results).contains_exactly([dir.path_join("a.png")])


func test_find_recurses_into_subdirectories_outside_res() -> void:
	var dir: String = create_temp_dir("find_external_sub")
	DirAccess.make_dir_recursive_absolute(dir.path_join("sub"))
	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.save_png(dir.path_join("sub/nested.png"))
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(dir, ".png")
	assert_array(results).contains_exactly([dir.path_join("sub/nested.png")])


func test_find_returns_empty_for_a_missing_external_directory() -> void:
	var dir: String = create_temp_dir("find_external_missing").path_join("nope")
	assert_array(WeavlyFileUtils.find_all_files_with_extension(dir, ".png")).is_empty()
	assert_logged(["Failed to open directory: " + dir])


# =====================
# load_variables: declared more than once
# =====================


func test_wvl_declaration_wins_over_a_resource_with_the_same_name() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables(
		engine, VARIABLES_DIR + "/dialogue", VARIABLES_DIR + "/resources"
	)
	assert_that(engine.variable_service.get_variable("score")).is_equal(1.0)
	var env: String = VARIABLES_DIR + "/dialogue/env.json"
	var resource: String = VARIABLES_DIR + "/resources/score.tres"
	assert_logged(
		[
			(
				"Variable 'score' is declared in both %s and %s, using the one in %s."
				% [env, resource, env]
			)
		]
	)


func test_two_resources_with_the_same_name_report_once() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, VARIABLES_DIR + "/twice")
	assert_logged(["Variable 'gold' is declared in both "])
	assert_bool(engine.variable_service.get_variable("gold") in [1.0, 2.0]).is_true()


func test_resource_default_outside_its_range_is_clamped() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables_from_resources(engine, VARIABLES_DIR + "/range")
	assert_that(engine.variable_service.get_variable("health")).is_equal(100.0)
	assert_logged(
		[
			(
				"Variable 'health' in %s/range/health.tres has default 150.0 outside its range,"
				% VARIABLES_DIR
			)
		]
	)


# =====================
# load_variables: extern declarations
# =====================


func test_a_resource_defines_an_extern_variable() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables(
		engine, VARIABLES_DIR + "/extern_dialogue", VARIABLES_DIR + "/extern_resources"
	)
	assert_that(engine.variable_service.get_variable("reputation")).is_equal(5.0)
	assert_bool(engine.variable_service.has("title")).is_false()


func test_a_resource_of_the_wrong_type_for_an_extern_is_rejected() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables(
		engine, VARIABLES_DIR + "/extern_dialogue", VARIABLES_DIR + "/extern_wrong"
	)
	assert_logged(
		[
			(
				"Variable 'title' in %s/extern_wrong/title.tres is a number, " % VARIABLES_DIR
				+ "but it's declared extern as a string."
			)
		]
	)
	assert_bool(engine.variable_service.has("title")).is_false()


func test_an_extern_without_a_resource_is_not_an_error() -> void:
	var engine = _make_engine()
	WeavlyFileUtils.load_variables(
		engine, VARIABLES_DIR + "/extern_dialogue", VARIABLES_DIR + "/range_does_not_exist"
	)
	assert_logged(["Failed to open directory: " + VARIABLES_DIR + "/range_does_not_exist"])
	assert_bool(engine.variable_service.has("reputation")).is_false()
	assert_bool(engine.variable_service.get_declaration("reputation").extern).is_true()
