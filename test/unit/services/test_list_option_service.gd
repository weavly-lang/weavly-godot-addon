extends GutTest

const _Service = preload("res://addons/weavly/src/services/implementations/list_option_service.gd")
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func _make_option(text: String = "option") -> WeavlyModel.Option:
	var body: Array[WeavlyModel.Statement] = []
	return WeavlyModel.Option.new(WeavlyModel.TrueExpression.new(), text, body, false)


func before_each() -> void:
	_engine = add_child_autofree(FakeEngine.new())
	_service = _Service.new()
	_service.initialize(_engine)


# =====================
# has_options
# =====================


func test_has_options_false_initially() -> void:
	assert_false(_service.has_options())


func test_has_options_always_false_after_add_options() -> void:
	_service.add_options([_make_option()])
	assert_false(_service.has_options())


# =====================
# add_options
# =====================


func test_add_options_emits_signal() -> void:
	var opts: Array[WeavlyModel.Option] = [_make_option()]
	watch_signals(_service)
	_service.add_options(opts)
	assert_signal_emitted_with_parameters(_service, "options_added", [opts])


# =====================
# choose_option
# =====================


func test_choose_option_adds_body_to_statement_service() -> void:
	var body: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	var opt := WeavlyModel.Option.new(WeavlyModel.TrueExpression.new(), "opt", body, false)
	_service.choose_option(opt)
	_engine.statement_service.advance_statements()
	assert_true(_engine.did_finish)


func test_choose_option_emits_signal() -> void:
	var opt := _make_option()
	watch_signals(_service)
	_service.choose_option(opt)
	assert_signal_emitted_with_parameters(_service, "option_chosen", [opt])


func test_choose_option_calls_engine_next() -> void:
	var opt := _make_option()
	_service.choose_option(opt)
	assert_true(_engine.did_next)
