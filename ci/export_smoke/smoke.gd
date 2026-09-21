extends Node

# Checks that the addon still finds and loads everything once the project is an
# exported binary: res:// paths live in a PCK, imported assets are renamed, and
# the working directory is wherever the executable was started from.

const ENGINE_SCENE = "res://addons/weavly/src/weavly_engine.tscn"
const EXTERNAL_DIR = "external_media"
const MAX_STEPS = 20
const VIDEO_SIZE = Vector2i(128, 96)
const MAX_DECODE_FRAMES = 120

var _failures: PackedStringArray = []
var _finished: bool = false


func _ready() -> void:
	var external_base: String = OS.get_executable_path().get_base_dir().path_join(EXTERNAL_DIR)

	var engine: WeavlyEngine = (load(ENGINE_SCENE) as PackedScene).instantiate()
	engine.dialogue_path = "res://dialogue/build"
	engine.image_path = "res://media/images"
	engine.character_path = "res://characters"
	engine.variable_path = "res://variables"
	engine.video_path = external_base.path_join("videos")
	engine.finished_dialogue.connect(func() -> void: _finished = true)
	add_child(engine)

	_check_discovery(engine)
	_check_packed_media(engine)
	await _check_external_media(engine, external_base)
	_run_dialogue(engine)

	if _failures.is_empty():
		print("Export smoke test passed.")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: %s" % failure)
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_discovery(engine: WeavlyEngine) -> void:
	_expect(engine.node_service.has("start"), "node 'start' not found in the packed dialogue JSON")
	_expect(engine.node_service.has("end"), "node 'end' not found in the packed dialogue JSON")
	_expect(engine.variable_service.has("score"), "variable 'score' not found in env.json")
	_expect(engine.variable_service.has("lives"), "variable 'lives' not found in variables/*.tres")
	_expect(
		engine.character_service.get_character(&"guide") != null,
		"character 'guide' not found in characters/*.tres"
	)


func _check_packed_media(engine: WeavlyEngine) -> void:
	var texture: Texture2D = engine.image_service.get_image("logo")
	_expect(texture != null, "packed image 'logo' did not load from the PCK")


func _check_external_media(engine: WeavlyEngine, external_base: String) -> void:
	var stream: VideoStream = engine.video_service.get_video("clip")
	_expect(stream != null, "external video 'clip' was not indexed next to the executable")
	if stream != null:
		await _check_video_decodes(stream)

	var banner_path: String = external_base.path_join("images/banner.png")
	engine.image_service.add_image("banner", banner_path)
	var banner: Texture2D = engine.image_service.get_image("banner")
	_expect(banner != null, "external image did not load from %s" % banner_path)


# is_playing() stays true for an unreadable file, so only a decoded frame proves real Theora.
func _check_video_decodes(stream: VideoStream) -> void:
	var player: VideoStreamPlayer = VideoStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()

	var texture: Texture2D = null
	for i in MAX_DECODE_FRAMES:
		texture = player.get_video_texture()
		if texture != null and texture.get_width() > 0:
			break
		await get_tree().process_frame

	if texture == null or texture.get_width() == 0:
		_failures.append("external video 'clip' did not decode a frame")
		player.queue_free()
		return

	var size: Vector2i = Vector2i(texture.get_width(), texture.get_height())
	_expect(size == VIDEO_SIZE, "decoded video frame is %s, expected %s" % [size, VIDEO_SIZE])
	player.queue_free()


func _run_dialogue(engine: WeavlyEngine) -> void:
	engine.start("start")
	var steps: int = 0
	while not _finished and steps < MAX_STEPS:
		engine.next()
		steps += 1

	_expect(_finished, "dialogue did not reach finish within %d steps" % MAX_STEPS)
	_expect(
		engine.variable_service.get_variable("score") == 7.0,
		"score is %s, expected 7.0" % engine.variable_service.get_variable("score")
	)
