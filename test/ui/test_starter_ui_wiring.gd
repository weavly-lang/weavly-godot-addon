extends WeavlyTestSuite

# Engine wiring every starter UI shares, checked across all of them.

const FIXTURE = "res://test/fixtures/ui/debug/build"
const SERVICES: Array[String] = [
	"character", "command", "count", "image", "line", "option", "statement", "variable", "video"
]
const SCENES: Array[PackedScene] = [
	preload("res://addons/weavly/ui/novel/weavly_novel_ui.tscn"),
	preload("res://addons/weavly/ui/passage/weavly_passage_ui.tscn"),
	preload("res://addons/weavly/ui/card/weavly_card_ui.tscn"),
	preload("res://addons/weavly/ui/chat/weavly_chat_ui.tscn"),
	preload("res://addons/weavly/ui/bubble/weavly_bubble_ui.tscn"),
	preload("res://addons/weavly/ui/debug/weavly_debug_ui.tscn"),
]


func _make_engine() -> WeavlyEngine:
	var engine: WeavlyEngine = WeavlyEngine.new()
	engine.dialogue_path = FIXTURE
	add_child(auto_free(engine))
	return engine


# Signals of the engine and its services that still call into ui or one of its children.
func _connections_into(ui: Node, engine: WeavlyEngine) -> Array[String]:
	var emitters: Dictionary[String, Object] = {"engine": engine}
	for service: String in SERVICES:
		emitters[service + "_service"] = engine.get(service + "_service")
	var found: Array[String] = []
	for emitter_name: String in emitters:
		var emitter: Object = emitters[emitter_name]
		for info: Dictionary in emitter.get_signal_list():
			for connection: Dictionary in emitter.get_signal_connection_list(info["name"]):
				var target: Object = (connection["callable"] as Callable).get_object()
				if target == ui or (target is Node and ui.is_ancestor_of(target)):
					found.append("%s.%s" % [emitter_name, info["name"]])
	return found


func test_every_starter_ui_disconnects_everything_from_an_engine_it_leaves() -> void:
	for scene: PackedScene in SCENES:
		var engine: WeavlyEngine = _make_engine()
		var ui: WeavlyUI = auto_free(scene.instantiate())
		ui.engine = engine
		add_child(ui)
		assert_array(_connections_into(ui, engine)).is_not_empty()
		ui.engine = null
		(
			assert_array(_connections_into(ui, engine))
			. override_failure_message("%s stays connected" % scene.resource_path.get_file())
			. is_empty()
		)
	# The debug overlay's name dropdowns are only queued for freeing when the engine leaves.
	await await_idle_frame()
