extends WeavlyService
class_name WeavlyLineService

signal executed_narration_line(narration_line: WeavlyModel.NarrationLine)
signal executed_character_line(character_line: WeavlyModel.CharacterLine)


func execute_narration_line(narration_line: WeavlyModel.NarrationLine) -> void:
	pass


func execute_character_line(character_line: WeavlyModel.CharacterLine) -> void:
	pass
