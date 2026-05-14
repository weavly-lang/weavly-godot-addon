class_name WeavlyStatementService
extends WeavlyService

signal executed_narration_line(narration_line: WeavlyModel.NarrationLine)
signal executed_character_line(character_line: WeavlyModel.CharacterLine)


func pause() -> void:
	return


func resume() -> void:
	return


func is_paused() -> bool:
	return false


func clear_statements() -> void:
	pass


func add_statements(_statements: Array[WeavlyModel.Statement]) -> void:
	pass


func add_statement_groups(_groups: Array[Array]) -> void:
	pass


func advance_statements() -> void:
	pass


class Frame:
	extends RefCounted
	var _statements: Array[WeavlyModel.Statement]
	var _counter: int

	func _init(statements: Array[WeavlyModel.Statement], counter: int):
		self._statements = statements
		self._counter = counter

	func has_next() -> bool:
		return _counter < _statements.size()

	func get_current_statement() -> WeavlyModel.Statement:
		return _statements[_counter]

	func increase_counter() -> void:
		_counter += 1
