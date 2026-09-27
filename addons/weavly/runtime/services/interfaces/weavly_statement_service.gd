@abstract class_name WeavlyStatementService
extends WeavlyService

@abstract func pause() -> void

@abstract func resume() -> void

@abstract func is_paused() -> bool

@abstract func clear_statements() -> void

@abstract func add_statements(statements: Array[WeavlyModel.Statement]) -> void

@abstract func add_statement_groups(groups: Array[Array]) -> void

@abstract func advance_statements() -> void


class Frame:
	extends RefCounted
	var _statements: Array[WeavlyModel.Statement]
	var _counter: int = 0

	func _init(statements: Array[WeavlyModel.Statement]):
		self._statements = statements

	func has_next() -> bool:
		return _counter < _statements.size()

	func get_current_statement() -> WeavlyModel.Statement:
		return _statements[_counter]

	func increase_counter() -> void:
		_counter += 1
