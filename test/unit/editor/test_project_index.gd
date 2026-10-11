# gdlint:ignore = max-public-methods
extends GdUnitTestSuite

const _CITY = """@env
var energy: number = 3
extern var reputation: number
pool city
slot bob
meta toll: number = 1
func bonus(points: number): number
func fade_in()
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
const _USES = """@env
var gold: number = 3
pool city
meta cost: number = 1
@endenv

@node market
@meta
pool: city
cost: gold
@endmeta
Guide: You have {gold} gold.
@set gold = gold + market.cost
@draw city
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
	}
	for kind: WeavlyProjectIndex.Kind in expected:
		var name: String = expected[kind][0]
		assert_array(_names(index.find(kind, name))).is_equal(
			["%s:%d" % [name, expected[kind][1]]]
		)
	assert_array(_names(index.find(WeavlyProjectIndex.Kind.FUNCTION, "fade_in"))).is_equal(
		["fade_in:7"]
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


func test_scanning_no_folder_keeps_only_the_open_file() -> void:
	_write_file("a.wvl", "@node saved\n@endnode\n")
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.scan(_dir)
	index.set_open_file("C:/elsewhere/scratch.wvl", "@node scratch\n@endnode\n")
	index.scan("")
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "saved")).is_empty()
	assert_array(index.find(WeavlyProjectIndex.Kind.NODE, "scratch")).has_size(1)


func test_a_declaration_shows_its_line() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	var found: Array[WeavlyProjectIndex.Definition] = index.find(
		WeavlyProjectIndex.Kind.VARIABLE, "reputation"
	)
	assert_str(found[0].text).is_equal("extern var reputation: number")


func test_a_node_shows_its_header_and_meta_block() -> void:
	var index: WeavlyProjectIndex = _scanned(_CITY)
	var market: WeavlyProjectIndex.Definition = (
		index.find(WeavlyProjectIndex.Kind.NODE, "market")[0]
	)
	assert_str(market.text).is_equal(
		"@node market # stalls\n@meta\npool: city, night # both\nslot: bob\n@endmeta"
	)
	var harbor: WeavlyProjectIndex.Definition = (
		index.find(WeavlyProjectIndex.Kind.NODE, "harbor")[0]
	)
	assert_str(harbor.text).is_equal("@node harbor")


func test_a_character_declaration_is_a_character() -> void:
	var definitions: Array[WeavlyProjectIndex.Definition] = WeavlyProjectIndex.parse(
		"a.wvl", "@env\ncharacter Guide\nvar friend: character = Guide\n@endenv"
	)
	assert_int(definitions[0].kind).is_equal(WeavlyProjectIndex.Kind.CHARACTER)
	assert_str(definitions[0].name).is_equal("Guide")
	assert_int(definitions[1].kind).is_equal(WeavlyProjectIndex.Kind.VARIABLE)


func test_kind_of_a_name_follows_the_open_file() -> void:
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.set_open_file("a.wvl", "@env\ncharacter Guide\n@endenv\n@node Start\n@endnode")
	assert_int(index.kind_of("Guide")).is_equal(WeavlyProjectIndex.Kind.CHARACTER)
	assert_int(index.kind_of("Start")).is_equal(WeavlyProjectIndex.Kind.NODE)
	assert_int(index.kind_of("nowhere")).is_equal(-1)
	index.set_open_file("a.wvl", "@env\nvar Guide: number = 1\n@endenv")
	assert_int(index.kind_of("Guide")).is_equal(WeavlyProjectIndex.Kind.VARIABLE)
	assert_int(index.kind_of("Start")).is_equal(-1)


func _uses(index: WeavlyProjectIndex, kind: WeavlyProjectIndex.Kind, name: String) -> Array:
	return index.uses(kind, name).map(
		func(use: WeavlyProjectIndex.Use) -> String: return "%d:%d" % [use.line, use.column]
	)


func test_uses_are_found_by_line_and_column() -> void:
	var index: WeavlyProjectIndex = _scanned(_USES)
	assert_array(_uses(index, WeavlyProjectIndex.Kind.VARIABLE, "gold")).is_equal(
		["9:6", "11:17", "12:5"]
	)
	assert_array(_uses(index, WeavlyProjectIndex.Kind.NODE, "market")).is_equal(["12:19"])
	assert_array(_uses(index, WeavlyProjectIndex.Kind.META_KEY, "cost")).is_equal(["9:0", "12:26"])


func test_declarations_and_pool_entries_arent_uses() -> void:
	var index: WeavlyProjectIndex = _scanned(_USES)
	assert_array(_uses(index, WeavlyProjectIndex.Kind.POOL, "city")).is_equal(["13:6"])


func test_a_use_only_matches_the_kinds_it_can_be() -> void:
	var index: WeavlyProjectIndex = _scanned(_USES)
	assert_array(_uses(index, WeavlyProjectIndex.Kind.NODE, "cost")).is_empty()
	assert_array(_uses(index, WeavlyProjectIndex.Kind.FUNCTION, "gold")).is_empty()


func test_a_use_keeps_its_line() -> void:
	var index: WeavlyProjectIndex = _scanned(_USES)
	var use: WeavlyProjectIndex.Use = index.uses(WeavlyProjectIndex.Kind.VARIABLE, "gold")[0]
	assert_str(use.text).is_equal("cost: gold")
	assert_str(use.path.get_file()).is_equal("city.wvl")


func test_uses_follow_the_open_files_edits() -> void:
	var path: String = _write_file("a.wvl", "@node a\n@jump b\n@endnode\n")
	var index: WeavlyProjectIndex = WeavlyProjectIndex.new()
	index.scan(_dir)
	assert_array(index.uses(WeavlyProjectIndex.Kind.NODE, "b")).has_size(1)
	index.set_open_file(path, "@node a\n@jump c\n@endnode\n")
	assert_array(index.uses(WeavlyProjectIndex.Kind.NODE, "b")).is_empty()
	assert_array(index.uses(WeavlyProjectIndex.Kind.NODE, "c")).has_size(1)
