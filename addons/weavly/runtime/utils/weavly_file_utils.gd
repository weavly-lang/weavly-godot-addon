class_name WeavlyFileUtils

const ENV_FILE = "env.json"
const SOURCE_EXTENSION = ".wvl.json"
const MISSING_ENV = "Can't load '%s' without env.json; check dialogue_path or build the project."


static func find_all_files_with_extension(
	dir_path: String, extension: String
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
			results.append_array(find_all_files_with_extension(sub_path, extension))
			continue

		if entry.to_lower().ends_with(extension.to_lower()):
			results.append(dir_path.path_join(entry))

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


# The compiler writes the declarations to env.json and each source's nodes to its *.wvl.json.
static func load_dialogue(engine: WeavlyEngine, dialogue_dir: String) -> void:
	var env_path: String = dialogue_dir.path_join(ENV_FILE)
	if not FileAccess.file_exists(env_path):
		push_error(MISSING_ENV % dialogue_dir)
		return
	var env: Variant = load_json_file(env_path)
	if env is Dictionary:
		_load_env(engine, env, env_path)
	for file_path: String in find_all_files_with_extension(dialogue_dir, SOURCE_EXTENSION):
		var data: Variant = load_json_file(file_path)
		if data is Dictionary:
			for node: WeavlyModel.WeavlyNode in WeavlyDeserializer.read_nodes(data, file_path):
				engine.story.add_node(node)


static func _load_env(engine: WeavlyEngine, data: Dictionary, path: String) -> void:
	for variable: WeavlyModel.Variable in WeavlyDeserializer.read_variable_declarations(
		data, path
	):
		engine.story.add_variable(variable)
	for pool: String in WeavlyDeserializer.read_pool_names(data, path):
		engine.story.add_pool(pool)
	for slot: String in WeavlyDeserializer.read_slot_names(data, path):
		engine.story.add_slot(slot)
	var meta_keys: Dictionary[String, Variant] = WeavlyDeserializer.read_meta_keys(data, path)
	for key: String in meta_keys:
		engine.story.add_meta_key(key, meta_keys[key])
	for function: WeavlyModel.Signature in WeavlyDeserializer.read_functions(data, path):
		engine.story.add_function(function)
