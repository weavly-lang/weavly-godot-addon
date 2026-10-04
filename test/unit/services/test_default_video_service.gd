extends WeavlyTestSuite

# Only what the video service adds to WeavlyMediaIndex; grouping and duplicates are tested there.

const Service = preload(
	"res://addons/weavly/runtime/services/implementations/default_video_service.gd"
)

# Saved as a .tres (native resource) so no import step is needed in headless/CI runs.
const _FIXTURE_PATH = "res://test/fixtures/test_video.tres"
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _service: Service


func before_test() -> void:
	_service = Service.new()
	_service.initialize(auto_free(FakeEngine.new()))


func test_add_and_get_video() -> void:
	_service.add_media("intro", _FIXTURE_PATH)
	assert_object(_service.get_video("intro")).is_instanceof(VideoStream)


func test_get_missing_id_returns_null() -> void:
	assert_that(_service.get_video("missing")).is_null()
	assert_logged(["Video with id 'missing' doesn't exist"])


func test_failed_load_returns_null() -> void:
	_service.add_media("broken", "res://test/fixtures/nonexistent.ogv")
	assert_that(_service.get_video("broken")).is_null()
	assert_logged(
		[
			'Condition "found" is true. Returning: Ref<Resource>()',
			"Failed to load Video at path 'res://test/fixtures/nonexistent.ogv' for id 'broken'"
		]
	)


func test_the_group_pattern_groups_videos() -> void:
	_service.set_group_pattern("_\\d+$")
	_service.add_media("intro_1", _FIXTURE_PATH)
	_service.add_media("intro_2", _FIXTURE_PATH)
	assert_object(_service.get_video("intro")).is_instanceof(VideoStream)


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


func test_get_video_returns_null_for_a_missing_external_file() -> void:
	var path: String = create_temp_dir("video_external_missing").path_join("nope.ogv")
	_service.add_media("broken", path)
	assert_that(_service.get_video("broken")).is_null()
	assert_logged(["Failed to load Video at path"])
