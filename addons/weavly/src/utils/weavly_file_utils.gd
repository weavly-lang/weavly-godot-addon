class_name WeavlyFileUtils

const DUPLICATE_VARIABLE = "Variable '%s' is declared in both %s and %s, using the one in %s."
const DEFAULT_OUT_OF_RANGE = "Variable '%s' in %s has default %s outside its range, using %s."
const EXTERN_TYPE_MISMATCH = "Variable '%s' in %s is a %s, but it's declared extern as a %s."


static func find_all_files_with_extension(
	dir_path: String, extension: String
) -> PackedStringArray:
	return find_all_files_with_extensions(dir_path, [extension])


static func find_all_files_with_extensions(
	dir_path: String, extensions: PackedStringArray
) -> PackedStringArray:
	var results: PackedStringArray = []

	if not DirAccess.dir_exists_absolute(dir_path):
		push_error("Failed to open directory: " + dir_path)
		return results

	for entry: String in _list_directory(dir_path):
		if entry.begins_with("."):
			continue

		if entry.ends_with("/"):
			var sub_path: String = dir_path.path_join(entry.trim_suffix("/"))
			results.append_array(find_all_files_with_extensions(sub_path, extensions))
			continue

		for extension: String in extensions:
			if entry.to_lower().ends_with(extension):
				results.append(dir_path.path_join(entry))
				break

	return results


# Inside a PCK only ResourceLoader reports the original names of imported assets,
# but it lists res:// only, so paths outside the project use DirAccess. Both
# report subdirectories with a trailing "/".
static func _list_directory(dir_path: String) -> PackedStringArray:
	if dir_path.begins_with("res://"):
		return ResourceLoader.list_directory(dir_path)

	var entries: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return entries

	for directory_name: String in dir.get_directories():
		entries.append(directory_name + "/")
	entries.append_array(dir.get_files())
	return entries


static func load_json_file(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open " + path)
		return null

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)

	if err != OK:
		push_error("JSON parse error in %s at line %d" % [path, json.get_error_line()])
		return null

	return json.data


# Reads each JSON file once; .wvl declarations load before resources, so they win.
static func load_dialogue(
	engine: WeavlyEngine, dialogue_dir: String, variable_dir: String
) -> void:
	var sources: Dictionary[String, String] = {}
	for file_path: String in find_all_files_with_extension(dialogue_dir, ".json"):
		var data: Variant = load_json_file(file_path)
		if data is not Dictionary:
			continue
		if data.has(WeavlyDeserializer.KEY_NODES):
			for node: WeavlyModel.WeavlyNode in WeavlyDeserializer.compile_nodes(data, file_path):
				engine.node_service.add_node(node)
		if data.has(WeavlyDeserializer.KEY_DECLARATIONS):
			var variables: Array[WeavlyModel.Variable] = (
				WeavlyDeserializer.compile_variable_declarations(data, file_path)
			)
			for variable: WeavlyModel.Variable in variables:
				_add_variable(engine, variable, file_path, sources)
			for pool: String in WeavlyDeserializer.compile_pool_names(data, file_path):
				engine.node_service.add_pool(pool)
	load_variables_from_resources(engine, variable_dir, sources)


static func load_variables_from_resources(
	engine: WeavlyEngine, dir: String, sources: Dictionary[String, String] = {}
) -> void:
	for file_path: String in find_all_files_with_extension(dir, ".tres"):
		var resource: Resource = load(file_path)
		if resource is WeavlyVariable:
			var variable: WeavlyModel.Variable = resource.instantiate()
			if variable is WeavlyModel.NumberVariable:
				_clamp_default(variable, file_path)
			_add_variable(engine, variable, file_path, sources)


static func _add_variable(
	engine: WeavlyEngine,
	variable: WeavlyModel.Variable,
	source: String,
	sources: Dictionary[String, String],
) -> void:
	var id: String = variable.id
	if sources.has(id):
		var declared: WeavlyModel.Variable = engine.variable_service.get_declaration(id)
		if not declared.extern or variable.extern:
			push_error(DUPLICATE_VARIABLE % [id, sources[id], source, sources[id]])
			return
		if variable.get_type_name() != declared.get_type_name():
			push_error(
				(
					EXTERN_TYPE_MISMATCH
					% [id, source, variable.get_type_name(), declared.get_type_name()]
				)
			)
			return
	sources[id] = source
	engine.variable_service.add_variable(variable)


static func _clamp_default(variable: WeavlyModel.NumberVariable, source: String) -> void:
	var clamped: float = variable.clamp_value(variable.value)
	if clamped != variable.value:
		push_error(DEFAULT_OUT_OF_RANGE % [variable.id, source, variable.value, clamped])
		variable.value = clamped


static func index_media_from_files(service: WeavlyMediaService, dir: String) -> void:
	for file_path: String in find_all_files_with_extensions(dir, service.supported_extensions):
		service.add_media(media_id(dir, file_path), file_path)


# The path relative to dir without extension, so dir/alice/icon.png is alice/icon.
static func media_id(dir: String, file_path: String) -> String:
	var relative: String = file_path.trim_prefix(dir).replace("\\", "/").trim_prefix("/")
	return relative.get_basename()


static func index_characters_from_resources(engine: WeavlyEngine, dir: String) -> void:
	var file_paths: PackedStringArray = find_all_files_with_extension(dir, ".tres")
	for file_path: String in file_paths:
		var resource: Resource = load(file_path)
		if resource is WeavlyCharacter:
			engine.character_service.add_character(resource)
