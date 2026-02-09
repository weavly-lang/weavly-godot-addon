extends WeavlyStatementService

var _stack: Array[Frame] = []
var _paused = false


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func clear_statements() -> void:
	_stack = []


func add_statements(statements: Array[WeavlyModel.Statement]) -> void:
	var frame = Frame.new(statements, 0)
	_stack.push_back(frame)


func advance_statements() -> void:
	if _stack.is_empty():
		engine.finish()
		return
	
	var frame: Frame = _stack[-1]
	if not frame.has_next():
		_stack.pop_back()
		return
	
	var statement: WeavlyModel.Statement = frame.get_current_statement()
	WeavlyStatementExecutor.execute_statment(statement, engine)
	frame.increase_counter()
