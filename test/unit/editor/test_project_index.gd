extends GdUnitTestSuite

const _CITY = """@env
var energy: number = 3
extern var reputation: number
pool city
slot bob
meta toll: number = 1
func bonus(points: number): number
command fade_in()
@endenv

@node market # stalls
@meta
pool: city, night # both
slot: bob
@endmeta
pool: not_in_meta
@endnode

@node harbor
@endnode
"""

var _dir: String


func before_test() -> void:
	_dir = ProjectSettings.globalize_path(
		create_temp_dir("project_index_%d" % Time.get_ticks_usec())
	)


func _write_file(relative: String, text: String) -> String:
	var path: String = _dir.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path.simplify_path()


func _names(definitions: Array[WeavlyProjectIndex.Definition]) -> Array[String]:
	var names: Array[String] = []
	for definition: WeavlyProjectIndex.Definition in definitions:
		names.append("%s:%d" % [definition.name, definition.line])
	return names


func _scanned(text: String) -> WeavlyProjectIndex:
	_write_file("city.wvl", text)
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.scan(_dir)
	return index


func test_nodes_are_found_by_their_line() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	assert_array(_names(index.find(WeavlyProjectIndex.Kind.NODE, "market"))).is_equal(
		["market:10"]
	)
	assert_array(_names(index.find(WeavlyProjectIndex.Kind.NODE, "harbor"))).is_equal(
		["harbor:18"]
	)


func test_env_declarations_are_found_by_kind() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	var expected: Dictionary[WeavlyProjectIndex.Kind, Array] = {
		WeavlyProjectIndex.Kind.VARIABLE: ["energy", 1],
		WeavlyProjectIndex.Kind.POOL: ["city", 3],
		WeavlyProjectIndex.Kind.SLOT: ["bob", 4],
		WeavlyProjectIndex.Kind.META_KEY: ["toll", 5],
		WeavlyProjectIndex.Kind.FUNCTION: ["bonus", 6],
		WeavlyProjectIndex.Kind.COMMAND: ["fade_in", 7],
	}
	for kind: WeavlyProjectIndex.Kind in expected:
		var name: String = expected[kind][0]
		assert_array(_names(index.find(kind, name))).is_equal(
			["%s:%d" % [name, expected[kind][1]]]
		)


func test_an_extern_variable_is_a_variable() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	assert_array(_names(index.find(WeavlyProjectIndex.Kind.VARIABLE, "reputation"))).is_equal(
		["reputation:2"]
	)


func test_a_name_of_another_kind_isnt_found() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "city")).is_empty()


func test_pool_and_slot_members_come_from_the_meta_block() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	assert_array(_names(index.members(WeavlyProjectIndex.Kind.POOL, "city"))).is_equal(
		["market:10"]
	)
	assert_array(_names(index.members(WeavlyProjectIndex.Kind.POOL, "night"))).is_equal(
		["market:10"]
	)
	assert_array(_names(index.members(WeavlyProjectIndex.Kind.SLOT, "bob"))).is_equal(
		["market:10"]
	)


func test_a_pool_entry_outside_the_meta_block_is_ignored() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	assert_array(index.members(WeavlyProjectIndex.Kind.POOL, "not_in_meta")).is_empty()


func test_scan_reads_subfolders_and_skips_other_files() -> void:
	_write_file("src/a.wvl", "@node a\n@endnode\n")
	_write_file("src/deep/b.wvl", "@node b\n@endnode\n")
	_write_file("build/a.wvl.json", "@node c\n@endnode\n")
	_write_file(".hidden/d.wvl", "@node d\n@endnode\n")
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.scan(_dir)
	for id: String in ["a", "b"]:
		assert_array(index.find(WeavlyProjectIndex.Kind.NODE, id)).has_size(1)
	for id: String in ["c", "d"]:
		assert_array(index.find(WeavlyProjectIndex.Kind.NODE, id)).is_empty()


func test_definitions_in_several_files_are_all_found() -> void:
	_write_file("b.wvl", "@node twin\n@endnode\n")
	_write_file("a.wvl", "\n@node twin\n@endnode\n")
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.scan(_dir)
	var found: Array[WeavlyProjectIndex.Definition] = index.find(
		WeavlyProjectIndex.Kind.NODE, "twin"
	)
	(
		assert_array(
			found.map(func(d: WeavlyProjectIndex.Definition) -> String: return d.path.get_file())
		)
		. is_equal(["a.wvl", "b.wvl"])
	)


func test_a_deleted_file_is_dropped() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@endnode\n")
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.scan(_dir)
	DirAccess.remove_absolute(path)
	index.scan(_dir)
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "a")).is_empty()


func test_the_open_file_uses_its_unsaved_text() -> void:
	var path: String = _write_file("a.wvl", "@node saved\n@endnode\n")
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.set_open_file(path, "@node unsaved\n@endnode\n")
	index.scan(_dir)
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "saved")).is_empty()
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "unsaved")).has_size(1)


func test_a_file_no_longer_open_is_read_from_disk_again() -> void:
	var first: String = _write_file("a.wvl", "@node saved\n@endnode\n")
	var second: String = _write_file("b.wvl", "@node other\n@endnode\n")
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.set_open_file(first, "@node unsaved\n@endnode\n")
	index.scan(_dir)
	index.set_open_file(second, "@node other\n@endnode\n")
	index.scan(_dir)
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "saved")).has_size(1)
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "unsaved")).is_empty()


func test_an_open_file_outside_the_project_is_indexed() -> void:
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.set_open_file("C:/elsewhere/scratch.wvl", "@node scratch\n@endnode\n")
	index.scan(_dir)
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "scratch")).has_size(1)
