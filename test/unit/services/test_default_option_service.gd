extends GdUnitTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_option_service.gd"
)
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func _make_option(text: String = "option") -> WeavlyModel.Option:
	var body: Array[WeavlyModel.Statement] = []
	return WeavlyModel.Option.new(WeavlyModel.TrueExpression.new(), text, body, false)


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
	monitor_signals(_service, false)
	_service.add_options(opts)
	await assert_signal(_service).is_emitted("options_added", [opts])


# =====================
# choose_option
# =====================


func test_choose_option_clears_pending_options() -> void:
	var opt := _make_option()
	var opts: Array[WeavlyModel.Option] = [opt]
	_service.add_options(opts)
	_service.choose_option(opt)
	assert_bool(_service.has_options()).is_false()


func test_choose_option_adds_body_to_statement_service() -> void:
	var body: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	var opt := WeavlyModel.Option.new(WeavlyModel.TrueExpression.new(), "opt", body, false)
	_service.choose_option(opt)
	_engine.statement_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()


func test_choose_option_emits_signal() -> void:
	var opt := _make_option()
	monitor_signals(_service, false)
	_service.choose_option(opt)
	await assert_signal(_service).is_emitted("option_chosen", [opt])


func test_choose_option_calls_engine_next() -> void:
	var opt := _make_option()
	_service.choose_option(opt)
	assert_bool(_engine.did_next).is_true()
