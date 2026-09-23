extends WeavlyTestSuite

const Service = preload("res://addons/weavly/src/services/implementations/list_option_service.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func _make_option(text: String = "option") -> WeavlyModel.Option:
	var body: Array[WeavlyModel.Statement] = []
	return WeavlyModel.Option.new(WeavlyModel.TrueExpression.new(), text, body, false)


func _offer(option: WeavlyModel.Option) -> void:
	var options: Array[WeavlyModel.Option] = [option]
	_service.add_options(options)


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


func test_has_options_always_false_after_add_options() -> void:
	var opts: Array[WeavlyModel.Option] = [_make_option()]
	_service.add_options(opts)
	assert_bool(_service.has_options()).is_false()


# =====================
# add_options
# =====================


func test_add_options_emits_signal() -> void:
	var opts: Array[WeavlyModel.Option] = [_make_option()]
	monitor_signals(_service, false)
	_service.add_options(opts)
	await assert_signal(_service).is_emitted("options_added", [opts])


# =====================
# choose_option
# =====================


func test_choose_option_adds_body_to_statement_service() -> void:
	var body: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	var opt := WeavlyModel.Option.new(WeavlyModel.TrueExpression.new(), "opt", body, false)
	_offer(opt)
	_service.choose_option(opt)
	_engine.statement_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()


func test_choose_option_emits_signal() -> void:
	var opt := _make_option()
	_offer(opt)
	monitor_signals(_service, false)
	_service.choose_option(opt)
	await assert_signal(_service).is_emitted("option_chosen", [opt])


func test_choose_option_calls_engine_next() -> void:
	var opt := _make_option()
	_offer(opt)
	_service.choose_option(opt)
	assert_bool(_engine.did_next).is_true()


func test_choose_option_ignores_an_option_that_is_not_offered() -> void:
	var offered: WeavlyModel.Option = _make_option("offered")
	var stale: WeavlyModel.Option = _make_option("stale")
	_offer(offered)
	monitor_signals(_service, false)
	_service.choose_option(stale)
	assert_logged([], ["Can't choose option 'stale' because it isn't offered right now."])
	await assert_signal(_service).is_not_emitted("option_chosen")
	assert_bool(_engine.did_next).is_false()


func test_choose_option_twice_chooses_it_once() -> void:
	var option: WeavlyModel.Option = _make_option("twice")
	var chosen: Array[WeavlyModel.Option] = []
	_service.option_chosen.connect(func(o: WeavlyModel.Option) -> void: chosen.append(o))
	_offer(option)
	_service.choose_option(option)
	_service.choose_option(option)
	assert_logged([], ["Can't choose option 'twice' because it isn't offered right now."])
	assert_int(chosen.size()).is_equal(1)


func test_choose_option_ignores_a_hint() -> void:
	var body: Array[WeavlyModel.Statement] = []
	var hint: WeavlyModel.Option = WeavlyModel.Option.new(
		WeavlyModel.TrueExpression.new(), "locked", body, true
	)
	_offer(hint)
	monitor_signals(_service, false)
	_service.choose_option(hint)
	assert_logged([], ["Can't choose option 'locked' because it's a hint."])
	await assert_signal(_service).is_not_emitted("option_chosen")
	assert_bool(_service.pending_options.has(hint)).is_true()


# =====================
# clear_options
# =====================


func test_clear_options_drops_pending_options() -> void:
	_offer(_make_option())
	_service.clear_options()
	assert_that(_service.pending_options).is_empty()
