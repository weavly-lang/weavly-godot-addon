extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_video_service.gd"
)

# Saved as a .tres (native resource) so no import step is needed in headless/CI runs.
const _FIXTURE_PATH = "res://test/fixtures/test_video.tres"

var _service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(null)


# =====================
# add / get (no pattern)
# =====================


func test_add_and_get_video() -> void:
	_service.add_media("intro", _FIXTURE_PATH)
	assert_object(_service.get_video("intro")).is_instanceof(VideoStream)


func test_get_missing_id_returns_default() -> void:
	assert_that(_service.get_video("missing")).is_null()
	assert_logged(["Video with id 'missing' doesn't exist"])


func test_get_missing_id_returns_provided_default() -> void:
	var fallback: VideoStreamTheora = VideoStreamTheora.new()
	assert_that(_service.get_video("missing", fallback)).is_equal(fallback)
	assert_logged(["Video with id 'missing' doesn't exist"])


# =====================
# duplicate id (no pattern)
# =====================


func test_add_duplicate_keeps_the_first_and_reports_both() -> void:
	_service.add_media("intro", _FIXTURE_PATH)
	_service.add_media("intro", "res://test/fixtures/other.tres")
	assert_logged(
		["Video id 'intro' is used by both %s and res://test/fixtures/other.tres" % _FIXTURE_PATH]
	)
	assert_that(_service.get_video("intro")).is_not_null()


# =====================
# failed load
# =====================


func test_failed_load_returns_default() -> void:
	_service.add_media("broken", "res://test/fixtures/nonexistent.ogv")
	assert_that(_service.get_video("broken")).is_null()
	assert_logged(
		[
			'Condition "found" is true. Returning: Ref<Resource>()',
			"Failed to load Video at path 'res://test/fixtures/nonexistent.ogv' for id 'broken'"
		]
	)


# =====================
# grouping (pattern set)
# =====================


func test_grouping_strips_suffix() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_media("intro_1", _FIXTURE_PATH)
	_service.add_media("intro_2", _FIXTURE_PATH)
	assert_object(_service.get_video("intro")).is_instanceof(VideoStream)


func test_grouping_strips_mid_string_match() -> void:
	_service.set_group_pattern("_v\\d+")
	_service.add_media("intro_v1_wide", _FIXTURE_PATH)
	_service.add_media("intro_v2_wide", _FIXTURE_PATH)
	assert_object(_service.get_video("intro_wide")).is_instanceof(VideoStream)


func test_unmatched_id_is_singleton_with_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_media("title", _FIXTURE_PATH)
	assert_object(_service.get_video("title")).is_instanceof(VideoStream)


func test_grouped_and_ungrouped_coexist() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_media("intro_1", _FIXTURE_PATH)
	_service.add_media("title", _FIXTURE_PATH)
	assert_object(_service.get_video("intro")).is_instanceof(VideoStream)
	assert_object(_service.get_video("title")).is_instanceof(VideoStream)


func test_duplicate_is_reported_when_pattern_set() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_media("intro_1", _FIXTURE_PATH)
	_service.add_media("intro_1", _FIXTURE_PATH)
	assert_object(_service.get_video("intro")).is_instanceof(VideoStream)
	assert_logged(["Video id 'intro_1' is used by both"])


# =====================
# invalid pattern
# =====================


func test_invalid_pattern_falls_back_to_no_grouping() -> void:
	_service.set_group_pattern("[")
	assert_logged(
		[
			"1: missing terminating ] for character class",
			"Failed to compile video group_pattern '[', falling back to no grouping."
		]
	)
	_service.add_media("intro", _FIXTURE_PATH)
	assert_object(_service.get_video("intro")).is_instanceof(VideoStream)


func test_invalid_pattern_duplicate_is_still_reported() -> void:
	_service.set_group_pattern("[")
	assert_logged(
		[
			"1: missing terminating ] for character class",
			"Failed to compile video group_pattern '[', falling back to no grouping."
		]
	)
	_service.add_media("intro", _FIXTURE_PATH)
	_service.add_media("intro", "res://test/fixtures/other.tres")
	assert_logged(["Video id 'intro' is used by both"])


# =====================
# External paths (issue #57)
# =====================


func test_get_video_streams_a_file_outside_res() -> void:
	var path: String = create_temp_dir("video_external").path_join("intro.ogv")
	FileAccess.open(path, FileAccess.WRITE).close()
	_service.add_media("intro", path)
	var stream: VideoStream = _service.get_video("intro")
	assert_object(stream).is_instanceof(VideoStreamTheora)
	assert_str(stream.file).is_equal(path)


func test_get_video_returns_default_for_a_missing_external_file() -> void:
	var path: String = create_temp_dir("video_external_missing").path_join("nope.ogv")
	_service.add_media("broken", path)
	assert_that(_service.get_video("broken")).is_null()
	assert_logged(["Failed to load Video at path"])
