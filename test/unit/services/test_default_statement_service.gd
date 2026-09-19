extends GdUnitTestSuite

const Service = preload(
	"res://addons/weavly/src/services/implementations/default_statement_service.gd"
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
# Frame (pure)
# =====================


func test_frame_has_next_false_when_empty() -> void:
	var stmts: Array[WeavlyModel.Statement] = []
	var frame := WeavlyStatementService.Frame.new(stmts, 0)
	assert_bool(frame.has_next()).is_false()


func test_frame_has_next_true_when_statements_remain() -> void:
	var stmts: Array[WeavlyModel.Statement] = [WeavlyModel.Statement.new()]
	var frame := WeavlyStatementService.Frame.new(stmts, 0)
	assert_bool(frame.has_next()).is_true()


func test_frame_get_current_statement() -> void:
	var stmt := WeavlyModel.Statement.new()
	var stmts: Array[WeavlyModel.Statement] = [stmt]
	var frame := WeavlyStatementService.Frame.new(stmts, 0)
	assert_that(frame.get_current_statement()).is_equal(stmt)


func test_frame_increase_counter_advances_past_end() -> void:
	var stmts: Array[WeavlyModel.Statement] = [WeavlyModel.Statement.new()]
	var frame := WeavlyStatementService.Frame.new(stmts, 0)
	frame.increase_counter()
	assert_bool(frame.has_next()).is_false()


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


# =====================
# add_statements / add_statement_groups
# =====================


func test_add_statements_puts_frame_on_stack() -> void:
	var stmts: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	_service.add_statements(stmts)
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()


func test_add_statement_groups_creates_separate_frames() -> void:
	var stmts1: Array[WeavlyModel.Statement] = []
	var stmts2: Array[WeavlyModel.Statement] = []
	var groups: Array[Array] = [stmts1, stmts2]
	_service.add_statement_groups(groups)
	_service.advance_statements()  # pop empty frame 1
	_service.advance_statements()  # pop empty frame 2
	assert_bool(_engine.did_finish).is_false()
	_service.advance_statements()  # stack empty → finish
	assert_bool(_engine.did_finish).is_true()


func test_add_statement_groups_executes_first_group_first() -> void:
	var stmts1: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	var stmts2: Array[WeavlyModel.Statement] = []
	var groups: Array[Array] = [stmts1, stmts2]
	_service.add_statement_groups(groups)
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()


func test_add_statement_groups_does_not_reorder_the_callers_array() -> void:
	var first: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	var second: Array[WeavlyModel.Statement] = []
	var groups: Array[Array] = [first, second]
	_service.add_statement_groups(groups)
	assert_that(groups[0]).is_same(first)
	assert_that(groups[1]).is_same(second)


# =====================
# advance_statements
# =====================


func test_advance_calls_finish_on_empty_stack() -> void:
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()


func test_advance_pops_exhausted_frame() -> void:
	var stmts: Array[WeavlyModel.Statement] = []
	_service.add_statements(stmts)
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_false()
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()


func test_advance_executes_current_statement() -> void:
	var stmts: Array[WeavlyModel.Statement] = [WeavlyModel.FinishStatement.new()]
	_service.add_statements(stmts)
	assert_bool(_engine.did_finish).is_false()
	_service.advance_statements()
	assert_bool(_engine.did_finish).is_true()
