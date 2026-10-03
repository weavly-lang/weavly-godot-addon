extends GdUnitTestSuite

const NODE = WeavlyProjectIndex.Kind.NODE
const POOL = WeavlyProjectIndex.Kind.POOL
const SLOT = WeavlyProjectIndex.Kind.SLOT
const VARIABLE = WeavlyProjectIndex.Kind.VARIABLE
const META_KEY = WeavlyProjectIndex.Kind.META_KEY
const FUNCTION = WeavlyProjectIndex.Kind.FUNCTION
const COMMAND = WeavlyProjectIndex.Kind.COMMAND
const NAMES: Array = [NODE, POOL, SLOT]


# Resolves at the | in a line of a node body, or of the block the lines above open.
func _resolve(line: String, above: String = "@node here") -> WeavlySymbolResolver.Symbol:
	var lines: PackedStringArray = above.split("\n")
	var column: int = line.find("|")
	lines.append(line.replace("|", ""))
	return WeavlySymbolResolver.resolve(lines, lines.size() - 1, column)


func _kinds(line: String, above: String = "@node here") -> Array:
	var symbol: WeavlySymbolResolver.Symbol = _resolve(line, above)
	return [] if symbol == null else Array(symbol.kinds)


func test_jump_and_detour_name_a_node() -> void:
	assert_array(_kinds("@jump |market")).is_equal([NODE])
	assert_array(_kinds("@detour mar|ket")).is_equal([NODE])
	assert_str(_resolve("@jump mar|ket").name).is_equal("market")


func test_the_end_of_a_word_still_resolves() -> void:
	assert_str(_resolve("@jump market|").name).is_equal("market")


func test_an_arrow_and_a_node_option_name_a_node() -> void:
	assert_array(_kinds('@option "Go" -> |market')).is_equal([NODE])
	assert_array(_kinds("@option node(|market)")).is_equal([NODE])
	assert_array(_kinds("@option |node(market)")).is_empty()


func test_draw_names_pools() -> void:
	assert_array(_kinds("@draw city, |night")).is_equal([POOL])


func test_a_pool_option_names_pools_but_not_its_parameters() -> void:
	assert_array(_kinds("@option pool(|city, limit: 3)")).is_equal([POOL])
	assert_array(_kinds("@option pool(city, |limit: 3)")).is_empty()
	assert_array(_kinds("@option pool(city, limit: |cap)")).is_equal(NAMES)


func test_variables_and_commands_go_by_their_marker() -> void:
	assert_array(_kinds("@set $|energy = 1")).is_equal([VARIABLE])
	assert_array(_kinds("$|guide: Hello.")).is_equal([VARIABLE])
	assert_array(_kinds("@|fade_in")).is_equal([COMMAND])


func test_a_call_names_a_function() -> void:
	assert_array(_kinds("@if |bonus(2) > 1: @jump x")).is_equal([FUNCTION])


func test_a_bare_name_in_an_expression_can_be_any_name() -> void:
	assert_array(_kinds("@if visited(|market): @jump x")).is_equal(NAMES)


func test_dialogue_text_isnt_code() -> void:
	assert_array(_kinds("Go to |market now.")).is_empty()
	assert_array(_kinds("$guide: Go to |market.")).is_empty()
	assert_array(_kinds("> Guide: Go to |market.")).is_empty()
	assert_array(_kinds('@option "Visit |market" -> x')).is_empty()
	assert_array(_kinds("@if $x > 1: Go to |market.")).is_empty()


func test_an_interpolation_is_code() -> void:
	assert_array(_kinds("Seen {visited(|market)} times.")).is_equal(NAMES)
	assert_array(_kinds('@option "Seen {visited(|market)}" -> x')).is_equal(NAMES)
	assert_array(_kinds("Escaped \\{visited(|market)} text.")).is_empty()


func test_an_inline_action_after_a_colon_is_a_line_of_its_own() -> void:
	assert_array(_kinds('@option "Go": @jump |market')).is_equal([NODE])
	assert_array(_kinds("@when $x: $|guide: Hi.")).is_equal([VARIABLE])


func test_comments_and_numbers_resolve_to_nothing() -> void:
	assert_object(_resolve("@jump x # see |market")).is_null()
	assert_object(_resolve("# |market")).is_null()
	assert_object(_resolve("@increase $x |2")).is_null()


func test_a_node_header_resolves_to_nothing() -> void:
	assert_object(_resolve("@node |market", "")).is_null()


func test_meta_keys_and_their_values() -> void:
	var above: String = "@node here\n@meta"
	assert_array(_kinds("|toll: 2", above)).is_equal([META_KEY])
	assert_array(_kinds("pool: city, |night", above)).is_equal([POOL])
	assert_array(_kinds("slot: |bob", above)).is_equal([SLOT])
	assert_array(_kinds("when: visited(|market)", above)).is_equal(NAMES)
	assert_array(_kinds('label_teaser: "Visit |market"', above)).is_empty()


func test_the_meta_block_ends_at_endmeta() -> void:
	assert_array(_kinds("pool: |city", "@node here\n@meta\n@endmeta")).is_empty()


func test_env_only_resolves_name_values() -> void:
	var above: String = "@env"
	assert_array(_kinds("var next: node = |market", above)).is_equal([NODE])
	assert_array(_kinds("var region: pool = |city", above)).is_equal([POOL])
	assert_array(_kinds("var |next: node = market", above)).is_empty()
	assert_array(_kinds("pool |city", above)).is_empty()


func test_outside_a_node_resolves_to_nothing() -> void:
	assert_object(_resolve("@jump |market", "@node here\n@endnode")).is_null()
