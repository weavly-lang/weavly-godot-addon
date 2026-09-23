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
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open " + path)
		return null

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)

	if err != OK:
		push_error("JSON parse error in %s at line %d" % [path, json.get_error_line()])
		return null

	return json.data


static func load_nodes_from_files(engine: WeavlyEngine, dir: String) -> void:
	var file_paths = find_all_files_with_extension(dir, ".json")

	var nodes: Array[WeavlyModel.WeavlyNode]
	for file_path in file_paths:
		var data: Variant = WeavlyFileUtils.load_json_file(file_path)
		if data is Dictionary and data.has(WeavlyDeserializer.KEY_NODES):
			nodes.append_array(WeavlyDeserializer.compile_nodes(data, file_path))

	for node in nodes:
		engine.node_service.add_node(node)


# .wvl declarations load first, so they win over a resource with the same name.
static func load_variables(
	engine: WeavlyEngine, dialogue_dir: String, variable_dir: String
) -> void:
	var sources: Dictionary[String, String] = {}
	load_variables_from_env_files(engine, dialogue_dir, sources)
	load_variables_from_resources(engine, variable_dir, sources)


static func load_variables_from_env_files(
	engine: WeavlyEngine, dir: String, sources: Dictionary[String, String] = {}
) -> void:
	for file_path: String in find_all_files_with_extension(dir, ".json"):
		var data: Variant = WeavlyFileUtils.load_json_file(file_path)
		if not (data is Dictionary and data.has(WeavlyDeserializer.KEY_DECLARATIONS)):
			continue
		var variables: Array[WeavlyModel.Variable] = (
			WeavlyDeserializer.compile_variable_declarations(data, file_path)
		)
		for variable: WeavlyModel.Variable in variables:
			_add_variable(engine, variable, file_path, sources)


static func load_variables_from_resources(
	engine: WeavlyEngine, dir: String, sources: Dictionary[String, String] = {}
) -> void:
	for file_path: String in find_all_files_with_extension(dir, ".tres"):
		var res = load(file_path)
		if res is WeavlyNumberVariable or res is WeavlyStringVariable or res is WeavlyFlagVariable:
			var variable: WeavlyModel.Variable = res.instantiate()
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
	var declared: WeavlyModel.Variable = engine.variable_service.get_declaration(id)
	if sources.has(id) and declared != null and declared.extern and not variable.extern:
		if variable.get_type_name() != declared.get_type_name():
			push_error(
				(
					EXTERN_TYPE_MISMATCH
					% [id, source, variable.get_type_name(), declared.get_type_name()]
				)
			)
			return
	elif sources.has(id):
		push_error(DUPLICATE_VARIABLE % [id, sources[id], source, sources[id]])
		return
	sources[id] = source
	engine.variable_service.add_variable(variable)


static func _clamp_default(variable: WeavlyModel.NumberVariable, source: String) -> void:
	var clamped: float = variable.value
	if variable.min != null:
		clamped = maxf(variable.min, clamped)
	if variable.max != null:
		clamped = minf(variable.max, clamped)
	if clamped != variable.value:
		push_error(DEFAULT_OUT_OF_RANGE % [variable.id, source, variable.value, clamped])
		variable.value = clamped


static func index_videos_from_files(engine: WeavlyEngine, dir: String) -> void:
	var extensions: PackedStringArray = engine.video_service.supported_extensions
	var file_paths = find_all_files_with_extensions(dir, extensions)

	for file_path in file_paths:
		var id: String = file_path.get_file().get_basename()
		engine.video_service.add_video(id, file_path)


static func index_images_from_files(engine: WeavlyEngine, dir: String) -> void:
	var extensions: PackedStringArray = engine.image_service.supported_extensions
	var file_paths = find_all_files_with_extensions(dir, extensions)

	for file_path in file_paths:
		var id: String = file_path.get_file().get_basename()
		engine.image_service.add_image(id, file_path)


static func index_characters_from_resources(engine: WeavlyEngine, dir: String) -> void:
	var file_paths = find_all_files_with_extension(dir, ".tres")
	for file_path in file_paths:
		var res = load(file_path)
		if res is WeavlyCharacter:
			engine.character_service.add_character(res)


static func create_service(
	engine: WeavlyEngine, user_script: Script, default_script: Script, base_type: Variant
) -> Variant:
	var script_to_use = user_script if user_script != null else default_script
	var instance: WeavlyService = script_to_use.new()
	if is_instance_of(instance, base_type):
		instance.initialize(engine)
		return instance

	push_warning("%s must extend %s. Falling back to default." % [script_to_use, base_type])
	var default_instance: WeavlyService = default_script.new()
	default_instance.initialize(engine)
	return default_instance
