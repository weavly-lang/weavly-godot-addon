class_name WeavlyDefaultCharacterService
extends WeavlyCharacterService

const TYPE = "Character"

var _character_index: Dictionary[String, WeavlyCharacter] = {}


# Adds the WeavlyCharacter resources in the engine's character_path.
func initialize(engine: WeavlyEngine) -> void:
	super(engine)
	if engine.character_path.is_empty():
		return
	for path: String in WeavlyFileUtils.find_all_files_with_extension(
		engine.character_path, ".tres"
	):
		var resource: Resource = load(path)
		if resource is WeavlyCharacter:
			add_character(resource)


func has(id: String) -> bool:
	return _character_index.has(id)


func add_character(character: WeavlyCharacter) -> void:
	if _character_index.has(character.id):
		push_warning(EXISTING_ID % [TYPE, character.id])
		return
	_character_index[character.id] = character


func get_character(id: String) -> WeavlyCharacter:
	if not _character_index.has(id):
		push_error(MISSING_ID % [TYPE, id])
	return _character_index.get(id)
