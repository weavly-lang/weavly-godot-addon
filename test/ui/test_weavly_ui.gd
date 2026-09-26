extends WeavlyTestSuite

const RecordingUI = preload("res://test/helpers/recording_ui.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")


func _make_engine(engine_name: String) -> WeavlyEngine:
	var engine: WeavlyEngine = FakeEngine.new()
	engine.name = engine_name
	return engine


func _make_ui() -> WeavlyUI:
	var ui: WeavlyUI = RecordingUI.new()
	ui.name = "UI"
	return auto_free(ui)


func test_connects_an_engine_set_before_ready() -> void:
	var engine: WeavlyEngine = _make_engine("Engine")
	add_child(auto_free(engine))
	var ui: WeavlyUI = _make_ui()
	ui.engine = engine
	assert_array(ui.events).is_empty()
	add_child(ui)
	assert_array(ui.events).is_equal(["connect:Engine"])


func test_waits_for_an_engine_that_isnt_ready() -> void:
	var engine: WeavlyEngine = auto_free(_make_engine("Engine"))
	var ui: WeavlyUI = _make_ui()
	ui.engine = engine
	add_child(ui)
	assert_array(ui.events).is_empty()
	add_child(engine)
	assert_array(ui.events).is_equal(["connect:Engine"])


func test_connects_an_autoload_by_name() -> void:
	var engine: WeavlyEngine = auto_free(_make_engine("WeavlyTestAutoload"))
	get_tree().root.add_child(engine)
	var ui: WeavlyUI = _make_ui()
	ui.engine_autoload = &"WeavlyTestAutoload"
	add_child(ui)
	assert_object(ui.engine).is_same(engine)
	assert_array(ui.events).is_equal(["connect:WeavlyTestAutoload"])


func test_engine_wins_over_autoload() -> void:
	var autoload: WeavlyEngine = auto_free(_make_engine("WeavlyTestAutoload"))
	get_tree().root.add_child(autoload)
	var engine: WeavlyEngine = _make_engine("Engine")
	add_child(auto_free(engine))
	var ui: WeavlyUI = _make_ui()
	ui.engine = engine
	ui.engine_autoload = &"WeavlyTestAutoload"
	add_child(ui)
	assert_object(ui.engine).is_same(engine)
	assert_array(ui.events).is_equal(["connect:Engine"])
	assert_logged([], ["'UI' has both engine and engine_autoload set, using engine."])


func test_missing_autoload_is_an_error() -> void:
	var ui: WeavlyUI = _make_ui()
	ui.engine_autoload = &"Missing"
	add_child(ui)
	assert_object(ui.engine).is_null()
	assert_array(ui.events).is_empty()
	assert_logged(["'UI' can't find an autoload named 'Missing'."])


func test_autoload_that_isnt_an_engine_is_an_error() -> void:
	var node: Node = auto_free(Node.new())
	node.name = "WeavlyTestNotAnEngine"
	get_tree().root.add_child(node)
	var ui: WeavlyUI = _make_ui()
	ui.engine_autoload = &"WeavlyTestNotAnEngine"
	add_child(ui)
	assert_object(ui.engine).is_null()
	assert_logged(
		["'UI' can't use autoload 'WeavlyTestNotAnEngine' because it isn't a WeavlyEngine."]
	)


func test_swapping_engines_at_runtime_reconnects() -> void:
	var first: WeavlyEngine = _make_engine("First")
	var second: WeavlyEngine = _make_engine("Second")
	add_child(auto_free(first))
	add_child(auto_free(second))
	var ui: WeavlyUI = _make_ui()
	ui.engine = first
	add_child(ui)
	ui.engine = second
	ui.engine = null
	assert_array(ui.events).is_equal(
		["connect:First", "disconnect:First", "connect:Second", "disconnect:Second"]
	)


func test_replacing_an_engine_that_isnt_ready_stops_waiting_for_it() -> void:
	var waiting: WeavlyEngine = auto_free(_make_engine("Waiting"))
	var ui: WeavlyUI = _make_ui()
	ui.engine = waiting
	add_child(ui)
	ui.engine = null
	add_child(waiting)
	assert_array(ui.events).is_empty()
