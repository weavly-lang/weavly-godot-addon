@abstract class_name WeavlyLineService
extends WeavlyService

signal executed_narration_line(narration_line: WeavlyModel.NarrationLine)
signal executed_character_line(character_line: WeavlyModel.CharacterLine)


@abstract func execute_narration_line(narration_line: WeavlyModel.NarrationLine) -> void


@abstract func execute_character_line(character_line: WeavlyModel.CharacterLine) -> void
