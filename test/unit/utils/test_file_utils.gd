# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")
const DefaultImageService = preload(
	"res://addons/weavly/runtime/services/implementations/default_image_service.gd"
)

const FIXTURE_DIR = "res://test/fixtures/file_utils"
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
# load_dialogue: malformed input (issue #38)
# =====================


func test_load_dialogue_skips_malformed_files_without_crashing() -> void:
	# FIXTURE_DIR mixes an unparseable file, an array-root file, and dictionaries
	# without a "nodes" key alongside valid nodes and declarations. A single bad
	# file must not crash startup.
	var engine: WeavlyEngine = _make_engine()
	WeavlyFileUtils.load_dialogue(engine, FIXTURE_DIR)
	assert_bool(engine.node_service.has("start")).is_true()
	assert_that(engine.variable_service.get_variable("score")).is_equal(0.0)
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
# load_dialogue: extern declarations
# =====================


func test_an_extern_is_declared_without_a_value() -> void:
	var engine: WeavlyEngine = _make_engine()
	WeavlyFileUtils.load_dialogue(engine, VARIABLES_DIR + "/extern_dialogue")
	assert_bool(engine.variable_service.has("reputation")).is_false()
	assert_bool(engine.variable_service.get_declaration("reputation").extern).is_true()


# =====================
# index_media_from_files
# =====================


func _index_images(dir: String, group_pattern: String) -> WeavlyEngine:
	var engine: WeavlyEngine = _make_engine()
	engine.image_service = DefaultImageService.new()
	engine.image_service.initialize(engine)
	engine.image_service.set_group_pattern(group_pattern)
	engine.image_service.set_supported_extensions([".png", ".jpg"])
	WeavlyFileUtils.index_media_from_files(engine.image_service, dir)
	return engine


func _save_images(dir: String, files: Array[String]) -> void:
	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGB8)
	for file: String in files:
		DirAccess.make_dir_recursive_absolute(dir.path_join(file).get_base_dir())
		image.save_png(dir.path_join(file))


func _image_ids(engine: WeavlyEngine) -> Array:
	return engine.image_service.image_index.paths.keys()


func test_an_image_id_is_its_path_relative_to_the_folder() -> void:
	var dir: String = create_temp_dir("index_ids")
	_save_images(dir, ["splash.png", "backgrounds/bob.png", "characters/bob.png"])
	var engine: WeavlyEngine = _index_images(dir, "")
	assert_array(_image_ids(engine)).contains_exactly_in_any_order(
		["splash", "backgrounds/bob", "characters/bob"]
	)


func test_a_trailing_slash_on_the_folder_gives_the_same_ids() -> void:
	var dir: String = create_temp_dir("index_trailing_slash")
	_save_images(dir, ["alice/icon.png"])
	var engine: WeavlyEngine = _index_images(dir + "/", "")
	assert_array(_image_ids(engine)).contains_exactly_in_any_order(["alice/icon"])


func test_files_that_differ_only_in_extension_report_both_paths() -> void:
	var dir: String = create_temp_dir("index_duplicate")
	_save_images(dir, ["alice/icon.jpg", "alice/icon.png"])
	_index_images(dir, "")
	var first: String = dir.path_join("alice/icon.jpg")
	var second: String = dir.path_join("alice/icon.png")
	assert_logged(
		["Image id 'alice/icon' is used by both %s and %s, using %s." % [first, second, first]]
	)


func test_a_group_pattern_groups_numbered_files_per_folder() -> void:
	var dir: String = create_temp_dir("index_grouped")
	_save_images(dir, ["alice/icon_1.png", "alice/icon_2.png", "bob/icon_3.png"])
	var engine: WeavlyEngine = _index_images(dir, "_\\d+$")
	assert_array(_image_ids(engine)).contains_exactly_in_any_order(["alice/icon", "bob/icon"])
	assert_array(engine.image_service.image_index.paths["alice/icon"]).has_size(2)
