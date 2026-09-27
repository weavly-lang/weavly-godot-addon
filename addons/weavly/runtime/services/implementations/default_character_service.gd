extends WeavlyCharacterService

const TYPE = "Character"

var _character_index: Dictionary[String, WeavlyCharacter] = {}


func has(id: String) -> bool:
	return _character_index.has(id)


func add_character(character: WeavlyCharacter) -> void:
	if _character_index.has(character.id):
		push_warning(EXISTING_ID % [TYPE, character.id])
		return
	_character_index[character.id] = character


func get_character(id: String, default: WeavlyCharacter = null) -> WeavlyCharacter:
	if not _character_index.has(id):
		push_error(MISSING_ID % [TYPE, id, default])
	return _character_index.get(id, default)
