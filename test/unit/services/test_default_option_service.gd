extends WeavlyTestSuite

const Service = preload(
	"res://addons/weavly/runtime/services/implementations/default_option_service.gd"
)
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service: Service


func _make_option(text: String = "option") -> WeavlyModel.Option:
	return inline_option(text)


func _offer(option: WeavlyModel.Option) -> WeavlyModel.Option:
	var options: Array[WeavlyModel.Option] = [option]
	_service.add_options(options)
	return _service.pending_options[0]


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	_service = Service.new()
	_service.initialize(_engine)


# =====================
# has_options
# =====================


func test_has_options_false_initially() -> void:
	assert_bool(_service.has_options()).is_false()


# =====================
# add_options
# =====================


func test_add_options_stores_options() -> void:
	var opts: Array[WeavlyModel.Option] = [_make_option()]
	_service.add_options(opts)
	assert_bool(_service.has_options()).is_true()


func test_add_options_emits_signal() -> void:
	var opts: Array[WeavlyModel.Option] = [_make_option()]
	var added: Array[Array] = []
	_service.options_added.connect(func(o: Array[WeavlyModel.Option]) -> void: added.append(o))
	_service.add_options(opts)
	assert_array(added).is_equal([opts])


# =====================
# choose_option
# =====================


func test_choose_option_clears_pending_options() -> void:
	var opt: WeavlyModel.Option = _make_option()
	opt = _offer(opt)
	_service.choose_option(opt)
	assert_bool(_service.has_options()).is_false()


func test_choose_option_adds_body_to_statement_service() -> void:
	var body: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	var opt: WeavlyModel.Option = inline_option("opt", body)
	opt = _offer(opt)
	_service.choose_option(opt)
	_engine.statement_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()


func test_choose_option_emits_signal() -> void:
	var opt: WeavlyModel.Option = _make_option()
	opt = _offer(opt)
	var chosen: Array[WeavlyModel.Option] = []
	_service.option_chosen.connect(func(o: WeavlyModel.Option) -> void: chosen.append(o))
	_service.choose_option(opt)
	assert_array(chosen).is_equal([opt])


func test_choose_option_calls_engine_next() -> void:
	var opt: WeavlyModel.Option = _make_option()
	opt = _offer(opt)
	_service.choose_option(opt)
	assert_bool(_engine.did_next).is_true()


func test_choose_option_ignores_an_option_that_is_not_offered() -> void:
	var offered: WeavlyModel.Option = _make_option("offered")
	var stale: WeavlyModel.Option = _make_option("stale")
	offered = _offer(offered)
	var chosen: Array[WeavlyModel.Option] = []
	_service.option_chosen.connect(func(o: WeavlyModel.Option) -> void: chosen.append(o))
	_service.choose_option(stale)
	assert_logged([], ["Can't choose option 'stale' because it isn't offered right now."])
	assert_array(chosen).is_empty()
	assert_bool(_engine.did_next).is_false()


func test_choose_option_twice_chooses_it_once() -> void:
	var option: WeavlyModel.Option = _make_option("twice")
	var chosen: Array[WeavlyModel.Option] = []
	_service.option_chosen.connect(func(o: WeavlyModel.Option) -> void: chosen.append(o))
	option = _offer(option)
	_service.choose_option(option)
	_service.choose_option(option)
	assert_logged([], ["Can't choose option 'twice' because it isn't offered right now."])
	assert_int(chosen.size()).is_equal(1)


func test_choose_option_refuses_an_option_that_is_locked_now() -> void:
	var option: WeavlyModel.Option = _offer(inline_option("gone", [], false))
	_service.choose_option(option)
	assert_logged([], ["Can't choose option 'gone' because it's locked."])
	assert_bool(_service.has_options()).is_true()
	assert_bool(_engine.did_next).is_false()


func test_choosing_a_node_option_detours_into_its_node() -> void:
	var body: Array[WeavlyModel.Statement] = []
	_engine.node_service.add_node(WeavlyModel.WeavlyNode.new("shop", body))
	var option: WeavlyModel.Option = WeavlyModel.Option.new()
	option.node_id = "shop"
	option.text = "Shop"
	_service.choose_option(_offer(option))
	assert_str(_engine.last_detoured_node).is_equal("shop")
	assert_bool(_service.has_options()).is_false()


# =====================
# clear_options
# =====================


func test_clear_options_drops_pending_options() -> void:
	_offer(_make_option())
	_service.clear_options()
	assert_that(_service.pending_options).is_empty()
