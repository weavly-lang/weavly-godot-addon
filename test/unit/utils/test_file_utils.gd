# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

const FIXTURE_DIR = "res://test/fixtures/file_utils"
const BUILD_DIR = FIXTURE_DIR + "/build"
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
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(
		FIXTURE_DIR, ".json"
	)
	assert_array(results).is_not_empty()
	for path: String in results:
		assert_str(path).ends_with(".json")


func test_find_ignores_non_matching_extension() -> void:
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(
		FIXTURE_DIR, ".json"
	)
	assert_array(results).not_contains([FIXTURE_DIR + "/not_json.txt"])


func test_find_recurses_into_subdirectories() -> void:
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(
		FIXTURE_DIR, ".json"
	)
	assert_array(results).contains([FIXTURE_DIR + "/sub/nested.json"])


func test_find_skips_dot_files() -> void:
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(
		FIXTURE_DIR, ".json"
	)
	assert_array(results).not_contains([FIXTURE_DIR + "/.hidden.json"])


func test_find_returns_empty_for_missing_directory() -> void:
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(
		"res://test/fixtures/does_not_exist", ".json"
	)
	assert_array(results).is_empty()
	assert_logged(["Failed to open directory: res://test/fixtures/does_not_exist"])


func test_find_ignores_the_case_of_the_extension() -> void:
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(
		FIXTURE_DIR, ".JSON"
	)
	assert_array(results).contains([FIXTURE_DIR + "/plain.json"])


func test_find_returns_empty_when_no_matching_extension() -> void:
	var results: PackedStringArray = WeavlyFileUtils.find_all_files_with_extension(
		FIXTURE_DIR, ".xyz"
	)
	assert_array(results).is_empty()


# =====================
# load_json_file
# =====================


func test_load_json_returns_parsed_dictionary() -> void:
	var data: Variant = WeavlyFileUtils.load_json_file(PLAIN_PATH)
	assert_that(data).is_equal({"hello": "world", "count": 3.0})


func test_load_json_returns_null_on_invalid_json() -> void:
	assert_that(WeavlyFileUtils.load_json_file(INVALID_PATH)).is_null()
	assert_logged(["JSON parse error in res://test/fixtures/file_utils/invalid.json at line 0"])


func test_load_json_returns_null_on_missing_file() -> void:
	assert_that(WeavlyFileUtils.load_json_file(MISSING_PATH)).is_null()
	assert_logged(["Could not open res://test/fixtures/file_utils/does_not_exist.json"])


# =====================
# load_dialogue
# =====================


func test_load_dialogue_reads_env_json_and_every_wvl_json() -> void:
	var engine: WeavlyEngine = _make_engine()
	WeavlyFileUtils.load_dialogue(engine, BUILD_DIR)
	assert_that(engine.story.get_variable("score").value).is_equal(0.0)
	assert_bool(engine.story.has_node("start")).is_true()
	assert_bool(engine.story.has_node("more")).is_true()
	assert_bool(engine.story.has_node("ignored")).is_false()
	assert_logged(["JSON parse error in %s/broken.wvl.json" % BUILD_DIR])


func test_load_dialogue_without_env_json_is_an_error() -> void:
	var engine: WeavlyEngine = _make_engine()
	WeavlyFileUtils.load_dialogue(engine, FIXTURE_DIR + "/sub")
	assert_logged(
		[
			(
				"Can't load '%s/sub' without env.json; check dialogue_path or build the project."
				% FIXTURE_DIR
			)
		]
	)


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
# load_dialogue: extern declarations
# =====================


func test_an_extern_is_declared_without_a_value() -> void:
	var engine: WeavlyEngine = _make_engine()
	WeavlyFileUtils.load_dialogue(engine, VARIABLES_DIR + "/extern_dialogue")
	assert_bool(engine.variable_service.has("reputation")).is_false()
	assert_bool(engine.story.get_variable("reputation").extern).is_true()
