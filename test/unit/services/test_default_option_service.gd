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
# clear_options
# =====================


func test_clear_options_drops_pending_options() -> void:
	_offer(_make_option())
	_service.clear_options()
	assert_that(_service.pending_options).is_empty()
