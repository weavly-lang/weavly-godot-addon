extends WeavlyLineService


func execute_narration_line(narration_line: WeavlyModel.NarrationLine) -> void:
	engine.statement_service.pause()
	executed_narration_line.emit(WeavlyTextUtils.fill_narration_line(narration_line, engine))


func execute_character_line(character_line: WeavlyModel.CharacterLine) -> void:
	engine.statement_service.pause()
	executed_character_line.emit(WeavlyTextUtils.fill_character_line(character_line, engine))
