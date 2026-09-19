extends GdUnitTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/list_statement_service.gd"
)
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	_service = Service.new()
	_service.initialize(_engine)
	_engine.statement_service = _service


# =====================
# pause / resume / is_paused
# =====================


func test_not_paused_initially() -> void:
	assert_bool(_service.is_paused()).is_false()


func test_pause() -> void:
	_service.pause()
	assert_bool(_service.is_paused()).is_true()


func test_resume_clears_paused() -> void:
	_service.pause()
	_service.resume()
	assert_bool(_service.is_paused()).is_false()


func test_add_statement_groups_does_not_reorder_the_callers_array() -> void:
	var first: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	var second: Array[WeavlyModel.Statement] = []
	var groups: Array[Array] = [first, second]
	_service.add_statement_groups(groups)
	assert_that(groups[0]).is_same(first)
	assert_that(groups[1]).is_same(second)


# =====================
# advance_statements — empty stack
# =====================


func test_advance_pauses_on_empty_stack() -> void:
	_service.advance_statements()
	assert_bool(_service.is_paused()).is_true()


func test_advance_does_not_call_finish_on_empty_stack() -> void:
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_false()


# =====================
# advance_statements — with frames
# =====================


func test_advance_pops_exhausted_frame() -> void:
	var stmts: Array[WeavlyModel.Statement] = []
	_service.add_statements(stmts)
	_service.advance_statements()
	assert_bool(_service.is_paused()).is_false()


func test_advance_executes_current_statement() -> void:
	var stmts: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	_service.add_statements(stmts)
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()
