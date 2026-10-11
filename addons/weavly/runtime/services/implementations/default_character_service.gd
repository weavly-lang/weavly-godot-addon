class_name WeavlyDefaultCharacterService
extends WeavlyCharacterService

const MISSING_ID = "Character with id '%s' doesn't exist."
const EXISTING_ID = "Character with id '%s' already exists."
const MISSING_RESOURCE = "Character '%s' has no WeavlyCharacter resource, showing its id."

var _character_index: Dictionary[String, WeavlyCharacter] = {}
var _reported: Dictionary[String, bool] = {}


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
		push_warning(EXISTING_ID % character.id)
		return
	_character_index[character.id] = character


func get_character(id: String) -> WeavlyCharacter:
	if not _character_index.has(id):
		push_error(MISSING_ID % id)
	return _character_index.get(id)


# The resource's display_name, else the id; a game with character resources hears once about each
# character without one.
func get_display_name(id: String) -> String:
	if _character_index.has(id) and not _character_index[id].display_name.is_empty():
		return _character_index[id].display_name
	if not engine.character_path.is_empty() and not _reported.has(id):
		_reported[id] = true
		push_warning(MISSING_RESOURCE % id)
	return id
