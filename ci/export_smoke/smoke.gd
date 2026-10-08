extends Node

# Checks that the addon still finds and loads everything once the project is an
# exported binary: res:// paths live in a PCK and imported assets are renamed.

const ENGINE_SCENE = "res://addons/weavly/runtime/weavly_engine.tscn"
const MAX_STEPS = 20

var _failures: PackedStringArray = []
var _finished: bool = false


func _ready() -> void:
	var engine: WeavlyEngine = (load(ENGINE_SCENE) as PackedScene).instantiate()
	engine.dialogue_path = "res://dialogue/build"
	engine.character_path = "res://characters"
	engine.finished_dialogue.connect(func() -> void: _finished = true)
	add_child(engine)

	_check_discovery(engine)
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
	_expect(engine.story.has_node("start"), "node 'start' not found in the packed dialogue JSON")
	_expect(engine.story.has_node("end"), "node 'end' not found in the packed dialogue JSON")
	_expect(engine.story.get_variable("score") != null, "variable 'score' not found in env.json")
	_expect(
		engine.character_service.get_character("guide") != null,
		"character 'guide' not found in characters/*.tres"
	)


func _run_dialogue(engine: WeavlyEngine) -> void:
	engine.start("start")
	var steps: int = 0
	while not _finished and steps < MAX_STEPS:
		engine.next()
		steps += 1

	_expect(_finished, "dialogue did not reach finish within %d steps" % MAX_STEPS)
	_expect(
		engine.get_variable("score") == 7.0,
		"score is %s, expected 7.0" % engine.get_variable("score")
	)
