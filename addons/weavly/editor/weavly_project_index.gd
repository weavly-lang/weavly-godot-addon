@tool
class_name WeavlyProjectIndex
extends RefCounted

enum Kind { NODE, POOL, SLOT, VARIABLE, META_KEY, FUNCTION, COMMAND }

const _DECLARATION_KINDS: Dictionary[String, Kind] = {
	"var": Kind.VARIABLE,
	"pool": Kind.POOL,
	"slot": Kind.SLOT,
	"meta": Kind.META_KEY,
	"func": Kind.FUNCTION,
	"command": Kind.COMMAND,
}

static var _node_regex: RegEx = RegEx.create_from_string("^\\s*@node\\s+([A-Za-z_]\\w*)")
static var _end_node_regex: RegEx = RegEx.create_from_string("^\\s*@endnode\\b")
static var _env_regex: RegEx = RegEx.create_from_string("^\\s*@env\\b")
static var _end_env_regex: RegEx = RegEx.create_from_string("^\\s*@endenv\\b")
static var _meta_regex: RegEx = RegEx.create_from_string("^\\s*@meta\\b")
static var _end_meta_regex: RegEx = RegEx.create_from_string("^\\s*@endmeta\\b")
static var _declaration_regex: RegEx = RegEx.create_from_string(
	"^\\s*(?:extern\\s+)?(var|pool|slot|meta|func|command)\\s+([A-Za-z_]\\w*)"
)
static var _group_entry_regex: RegEx = RegEx.create_from_string("^\\s*(pool|slot)\\s*:([^#]*)")
static var _id_regex: RegEx = RegEx.create_from_string("^[A-Za-z_]\\w*$")


class Definition:
	extends RefCounted
	var kind: Kind
	var name: String
	var path: String
	# 0-based.
	var line: int
	# Nodes only: the pools and slots their @meta block names.
	var pools: PackedStringArray = []
	var slots: PackedStringArray = []


# Path -> its definitions.
var _files: Dictionary[String, Array] = {}
var _modified_times: Dictionary[String, int] = {}
var _open_path: String = ""


# Rereads the .wvl files under dir that changed since the last scan; the open file is skipped.
func scan(dir: String) -> void:
	var found: Dictionary[String, bool] = {}
	_collect_files(dir, found)
	for path: String in _files.keys():
		if path != _open_path and not found.has(path):
			_files.erase(path)
			_modified_times.erase(path)
	for path: String in found:
		if path == _open_path:
			continue
		var modified: int = FileAccess.get_modified_time(path)
		if _modified_times.get(path, -1) == modified:
			continue
		_modified_times[path] = modified
		_files[path] = parse(path, FileAccess.get_file_as_string(path))


# Indexes the open file from its unsaved text instead of the disk.
func set_open_file(path: String, text: String) -> void:
	path = path.simplify_path()
	if _open_path != "" and _open_path != path:
		_files.erase(_open_path)
		_modified_times.erase(_open_path)
	_open_path = path
	if path != "":
		_files[path] = parse(path, text)


func find(kind: Kind, name: String) -> Array[Definition]:
	var found: Array[Definition] = []
	for path: String in _sorted_paths():
		for definition: Definition in _files[path]:
			if definition.kind == kind and definition.name == name:
				found.append(definition)
	return found


# The nodes in a pool or slot, by file and line.
func members(kind: Kind, name: String) -> Array[Definition]:
	var found: Array[Definition] = []
	for path: String in _sorted_paths():
		for definition: Definition in _files[path]:
			if definition.kind != Kind.NODE:
				continue
			var groups: PackedStringArray = (
				definition.pools if kind == Kind.POOL else definition.slots
			)
			if name in groups:
				found.append(definition)
	return found


static func parse(path: String, text: String) -> Array[Definition]:
	var definitions: Array[Definition] = []
	var in_env: bool = false
	var in_meta: bool = false
	var node: Definition = null
	var lines: PackedStringArray = text.split("\n")
	for line: int in lines.size():
		var content: String = lines[line]
		if in_env:
			if _end_env_regex.search(content) != null:
				in_env = false
				continue
			var declaration: RegExMatch = _declaration_regex.search(content)
			if declaration != null:
				definitions.append(
					_definition(
						_DECLARATION_KINDS[declaration.get_string(1)],
						declaration.get_string(2),
						path,
						line
					)
				)
		elif in_meta:
			if _end_meta_regex.search(content) != null:
				in_meta = false
				continue
			var entry: RegExMatch = _group_entry_regex.search(content)
			if entry != null:
				var names: PackedStringArray = _ids(entry.get_string(2))
				if entry.get_string(1) == "pool":
					node.pools.append_array(names)
				else:
					node.slots.append_array(names)
		elif _env_regex.search(content) != null:
			in_env = true
		elif _node_regex.search(content) != null:
			node = _definition(Kind.NODE, _node_regex.search(content).get_string(1), path, line)
			definitions.append(node)
		elif node != null and _meta_regex.search(content) != null:
			in_meta = true
		elif _end_node_regex.search(content) != null:
			node = null
	return definitions


static func _definition(kind: Kind, name: String, path: String, line: int) -> Definition:
	var definition: Definition = Definition.new()
	definition.kind = kind
	definition.name = name
	definition.path = path
	definition.line = line
	return definition


static func _ids(value: String) -> PackedStringArray:
	var ids: PackedStringArray = []
	for part: String in value.split(","):
		var id: String = part.strip_edges()
		if _id_regex.search(id) != null:
			ids.append(id)
	return ids


static func _collect_files(dir: String, found: Dictionary[String, bool]) -> void:
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return
	for file: String in access.get_files():
		if file.get_extension() == "wvl":
			found[dir.path_join(file).simplify_path()] = true
	for subdir: String in access.get_directories():
		if not subdir.begins_with("."):
			_collect_files(dir.path_join(subdir), found)


func _sorted_paths() -> Array[String]:
	var paths: Array[String] = []
	paths.assign(_files.keys())
	paths.sort()
	return paths
