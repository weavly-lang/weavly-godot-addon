@abstract class_name WeavlyCharacterService
extends WeavlyService

@abstract func has(id: String) -> bool

@abstract func add_character(character: WeavlyCharacter) -> void

@abstract func get_character(id: String, default: WeavlyCharacter = null) -> WeavlyCharacter
