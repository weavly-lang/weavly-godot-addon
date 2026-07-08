class_name WeavlyFileUtils


static func find_all_files_with_extension(
	dir_path: String, extension: String
) -> PackedStringArray:
	return find_all_files_with_extensions(dir_path, [extension])


static func find_all_files_with_extensions(
	dir_path: String, extensions: PackedStringArray
) -> PackedStringArray:
	var results: PackedStringArray = []
	var dir = DirAccess.open(dir_path)

	if dir == null:
		push_error("Failed to open directory: " + dir_path)
		return results

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)

		if dir.current_is_dir():
			results.append_array(find_all_files_with_extensions(full_path, extensions))
			file_name = dir.get_next()
			continue

		for extension: String in extensions:
			if file_name.to_lower().ends_with(extension):
				results.append(full_path)
				break

		file_name = dir.get_next()

	dir.list_dir_end()

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
		var data: Dictionary = WeavlyFileUtils.load_json_file(file_path)
		if data.has(WeavlyDeserializer.KEY_NODES):
			nodes.append_array(WeavlyDeserializer.compile_nodes(data))

	for node in nodes:
		engine.node_service.add_node(node)


static func load_variables_from_env_files(engine: WeavlyEngine, dir: String) -> void:
	var file_paths = find_all_files_with_extension(dir, ".json")

	var variables: Array[WeavlyModel.Variable]
	for file_path in file_paths:
		var data: Dictionary = WeavlyFileUtils.load_json_file(file_path)
		if data.has(WeavlyDeserializer.KEY_DECLARATIONS):
			variables.append_array(WeavlyDeserializer.compile_variable_declarations(data))

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
