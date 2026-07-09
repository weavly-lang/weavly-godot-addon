class_name WeavlyFileUtils


static func find_all_files_with_extension(
	dir_path: String, extension: String
) -> PackedStringArray:
	return find_all_files_with_extensions(dir_path, [extension])


static func find_all_files_with_extensions(
	dir_path: String, extensions: PackedStringArray
) -> PackedStringArray:
	var results: PackedStringArray = []

	# ResourceLoader.list_directory is export-safe: inside a PCK it resolves
	# imported assets (.import/.remap companions, text-to-binary .tres) back to
	# their original names, which a raw DirAccess listing does not. It returns
	# [] for a missing directory without erroring, so gate on existence to keep
	# the previous "failed to open" signal. Subdirectories come back with a
	# trailing "/"; non-resource files (e.g. .txt) are omitted, but every type
	# this addon indexes (.json/.tres/.png/.jpg/.ogv) is a resource.
	if not DirAccess.dir_exists_absolute(dir_path):
		push_error("Failed to open directory: " + dir_path)
		return results

	for entry: String in ResourceLoader.list_directory(dir_path):
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


static func load_variables_from_env_files(engine: WeavlyEngine, dir: String) -> void:
	var file_paths = find_all_files_with_extension(dir, ".json")

	var variables: Array[WeavlyModel.Variable]
	for file_path in file_paths:
		var data: Variant = WeavlyFileUtils.load_json_file(file_path)
		if data is Dictionary and data.has(WeavlyDeserializer.KEY_DECLARATIONS):
			variables.append_array(
				WeavlyDeserializer.compile_variable_declarations(data, file_path)
			)

	for variable: WeavlyModel.Variable in variables:
		engine.variable_service.add_variable(variable)


static func load_variables_from_resources(engine: WeavlyEngine, dir: String) -> void:
	var file_paths = find_all_files_with_extension(dir, ".tres")
	for file_path in file_paths:
		var res = load(file_path)
		if res is WeavlyNumberVariable or res is WeavlyStringVariable or res is WeavlyFlagVariable:
			var variable: WeavlyModel.Variable = res.instantiate()
			engine.variable_service.add_variable(variable)


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


static func create_visited_flags_from_nodes(
	engine: WeavlyEngine, nodes: Array[WeavlyModel.WeavlyNode]
) -> void:
	for node: WeavlyModel.WeavlyNode in nodes:
		var flag: WeavlyModel.FlagVariable = WeavlyModel.FlagVariable.new(node.id, false)
		engine.variable_service.add_variable(flag)
