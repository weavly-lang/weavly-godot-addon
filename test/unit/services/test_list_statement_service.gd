extends GutTest

const Service = preload(
	"res://addons/weavly/src/services/implementations/list_statement_service.gd"
)
const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine
var _service


func before_each() -> void:
	_engine = add_child_autofree(FakeEngine.new())
	_service = Service.new()
	_service.initialize(_engine)
	_engine.statement_service = _service


# =====================
# pause / resume / is_paused
# =====================


func test_not_paused_initially() -> void:
	assert_false(_service.is_paused())


func test_pause() -> void:
	_service.pause()
	assert_true(_service.is_paused())


func test_resume_clears_paused() -> void:
	_service.pause()
	_service.resume()
	assert_false(_service.is_paused())


# =====================
# advance_statements — empty stack
# =====================


func test_advance_pauses_on_empty_stack() -> void:
	_service.advance_statements()
	assert_true(_service.is_paused())


func test_advance_does_not_call_finish_on_empty_stack() -> void:
	_service.advance_statements()
	assert_false(_engine.did_finish)


# =====================
# advance_statements — with frames
# =====================


func test_advance_pops_exhausted_frame() -> void:
	var stmts: Array[WeavlyModel.Statement] = []
	_service.add_statements(stmts)
	_service.advance_statements()
	assert_false(_service.is_paused())


func test_advance_executes_current_statement() -> void:
	var stmts: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	_service.add_statements(stmts)
	_service.advance_statements()
	assert_true(_engine.did_finish)
