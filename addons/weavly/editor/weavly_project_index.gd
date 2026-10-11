@tool
class_name WeavlyProjectIndex
extends RefCounted

enum Kind { NODE, POOL, SLOT, CHARACTER, VARIABLE, META_KEY, FUNCTION }

const DECLARATION_KINDS: Dictionary[String, Kind] = {
	"var": Kind.VARIABLE,
	"pool": Kind.POOL,
	"slot": Kind.SLOT,
	"character": Kind.CHARACTER,
	"meta": Kind.META_KEY,
	"func": Kind.FUNCTION,
}

static var declaration_regex: RegEx = RegEx.create_from_string(
	"^\\s*(?:extern\\s+)?(var|pool|slot|character|meta|func)\\s+([A-Za-z_]\\w*)"
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
	# What a hover shows: the declaration line, or a node's header and @meta block.
	var text: String


# A line that uses a name; a line using it twice is one use.
class Use:
	extends RefCounted
	var kinds: Array[Kind] = []
	var path: String
	# 0-based.
	var line: int
	var column: int
	var text: String


# Path -> its definitions.
var _files: Dictionary[String, Array] = {}
# Path -> its text, for finding uses later.
var _texts: Dictionary[String, String] = {}
# Path -> name -> its uses; filled when first asked.
var _uses: Dictionary[String, Dictionary] = {}
var _modified_times: Dictionary[String, int] = {}
var _open_path: String = ""
# Name -> the kind of its first definition; rebuilt after a change.
var _kinds: Dictionary[String, Kind] = {}
var _kinds_stale: bool = true


# Rereads the .wvl files under dir that changed since the last scan and drops the rest;
# the open file is skipped. An empty dir keeps only the open file. True when anything changed.
func scan(dir: String) -> bool:
	var found: Dictionary[String, bool] = {}
	if dir != "":
		_collect_files(dir, found)
	var changed: bool = false
	for path: String in _files.keys():
		if path != _open_path and not found.has(path):
			_forget(path)
			changed = true
	for path: String in found:
		if path == _open_path:
			continue
		var modified: int = FileAccess.get_modified_time(path)
		if _modified_times.get(path, -1) == modified:
			continue
		_modified_times[path] = modified
		_read(path, FileAccess.get_file_as_string(path))
		changed = true
	_kinds_stale = _kinds_stale or changed
	return changed


# Indexes the open file from its unsaved text instead of the disk.
func set_open_file(path: String, text: String) -> void:
	path = path.simplify_path()
	if _open_path != "" and _open_path != path:
		_forget(_open_path)
	_open_path = path
	if path != "":
		_read(path, text)
	_kinds_stale = true


func _read(path: String, text: String) -> void:
	_files[path] = parse(path, text)
	_texts[path] = text
	_uses.erase(path)


func _forget(path: String) -> void:
	_files.erase(path)
	_texts.erase(path)
	_uses.erase(path)
	_modified_times.erase(path)


# The kind of the definition with the name, or -1 when nothing has it.
func kind_of(name: String) -> int:
	if _kinds_stale:
		_kinds.clear()
		for path: String in _sorted_paths():
			for definition: Definition in _files[path]:
				if not _kinds.has(definition.name):
					_kinds[definition.name] = definition.kind
		_kinds_stale = false
	return _kinds.get(name, -1)


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


# Where the name is used as one of kind, by file and line.
func uses(kind: Kind, name: String) -> Array[Use]:
	var found: Array[Use] = []
	for path: String in _sorted_paths():
		if not _uses.has(path):
			_uses[path] = find_uses(path, _texts[path])
		for use: Use in _uses[path].get(name, []):
			if kind in use.kinds:
				found.append(use)
	return found


# Name -> the lines that use it, leaving out declarations and pool or slot entries.
static func find_uses(path: String, text: String) -> Dictionary[String, Array]:
	var found: Dictionary[String, Array] = {}
	var lines: PackedStringArray = text.split("\n")
	var blocks: PackedInt32Array = WeavlyLineScanner.blocks(lines)
	for line: int in lines.size():
		var on_line: Dictionary[String, Use] = {}
		for symbol: WeavlySymbolResolver.Symbol in WeavlySymbolResolver.symbols(
			lines[line], blocks[line]
		):
			if symbol.role != WeavlySymbolResolver.Role.USE:
				continue
			var use: Use = on_line.get(symbol.name)
			if use == null:
				use = Use.new()
				use.path = path
				use.line = line
				use.column = symbol.column
				use.text = lines[line].strip_edges()
				on_line[symbol.name] = use
				if not found.has(symbol.name):
					found[symbol.name] = []
				found[symbol.name].append(use)
			for kind: Kind in symbol.kinds:
				if kind not in use.kinds:
					use.kinds.append(kind)
	return found


static func parse(path: String, text: String) -> Array[Definition]:
	var definitions: Array[Definition] = []
	var node: Definition = null
	var lines: PackedStringArray = text.split("\n")
	var blocks: PackedInt32Array = WeavlyLineScanner.blocks(lines)
	for line: int in lines.size():
		var content: String = lines[line]
		match blocks[line]:
			WeavlyLineScanner.Block.ENV:
				var declaration: RegExMatch = declaration_regex.search(content)
				if declaration != null:
					var definition: Definition = _definition(
						DECLARATION_KINDS[declaration.get_string(1)],
						declaration.get_string(2),
						path,
						line
					)
					definition.text = content.strip_edges()
					definitions.append(definition)
			WeavlyLineScanner.Block.META:
				if node == null:
					continue
				node.text += "\n" + content.strip_edges(false, true)
				var entry: RegExMatch = _group_entry_regex.search(content)
				if entry != null:
					var names: PackedStringArray = _ids(entry.get_string(2))
					if entry.get_string(1) == "pool":
						node.pools.append_array(names)
					else:
						node.slots.append_array(names)
			_:
				match WeavlyLineScanner.directive(content):
					"@node":
						var name: String = WeavlyLineScanner.node_name(content)
						node = null if name == "" else _definition(Kind.NODE, name, path, line)
						if node != null:
							node.text = content.strip_edges()
							definitions.append(node)
					"@meta":
						if node != null and blocks[line] == WeavlyLineScanner.Block.BODY:
							node.text += "\n" + content.strip_edges()
					"@endnode":
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
