@abstract class_name WeavlyCharacterService
extends WeavlyService

@abstract func has(id: String) -> bool

@abstract func get_character(id: String) -> WeavlyCharacter

# The name a line shows for a declared character, resolved each time a line runs.
@abstract func get_display_name(id: String) -> String
