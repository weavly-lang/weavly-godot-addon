@abstract class_name WeavlyCharacterService
extends WeavlyService

@abstract func add_character(character: WeavlyCharacter) -> void

@abstract func get_character(id: StringName, default: WeavlyCharacter = null) -> WeavlyCharacter
