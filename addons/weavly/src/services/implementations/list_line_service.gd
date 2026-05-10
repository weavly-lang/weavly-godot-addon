extends WeavlyLineService


func execute_narration_line(narration_line: WeavlyModel.NarrationLine) -> void:
	executed_narration_line.emit(narration_line)


func execute_character_line(character_line: WeavlyModel.CharacterLine) -> void:
	executed_character_line.emit(character_line)
