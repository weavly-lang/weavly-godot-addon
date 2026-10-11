# gdlint:ignore = max-public-methods
extends GdUnitTestSuite

const NODE = WeavlyProjectIndex.Kind.NODE
const POOL = WeavlyProjectIndex.Kind.POOL
const SLOT = WeavlyProjectIndex.Kind.SLOT
const CHARACTER = WeavlyProjectIndex.Kind.CHARACTER
const VARIABLE = WeavlyProjectIndex.Kind.VARIABLE
const META_KEY = WeavlyProjectIndex.Kind.META_KEY
const FUNCTION = WeavlyProjectIndex.Kind.FUNCTION
const NAMES: Array = [NODE, POOL, SLOT, CHARACTER, VARIABLE]
const SPEAKERS: Array = [CHARACTER, VARIABLE]
const NODE_TARGETS: Array = [NODE, VARIABLE]
const POOL_TARGETS: Array = [POOL, VARIABLE]


# Resolves at the | in a line of a node body, or of the block the lines above open.
func _resolve(line: String, above: String = "@node here") -> WeavlySymbolResolver.Symbol:
	var lines: PackedStringArray = above.split("\n")
	var column: int = line.find("|")
	lines.append(line.replace("|", ""))
	return WeavlySymbolResolver.resolve(lines, lines.size() - 1, column)


func _kinds(line: String, above: String = "@node here") -> Array:
	var symbol: WeavlySymbolResolver.Symbol = _resolve(line, above)
	return [] if symbol == null else Array(symbol.kinds)


func test_jump_and_detour_name_a_node_or_a_node_variable() -> void:
	assert_array(_kinds("@jump |market")).is_equal(NODE_TARGETS)
	assert_array(_kinds("@detour mar|ket")).is_equal(NODE_TARGETS)
	assert_str(_resolve("@jump mar|ket").name).is_equal("market")


func test_the_end_of_a_word_still_resolves() -> void:
	assert_str(_resolve("@jump market|").name).is_equal("market")


func test_a_node_option_names_a_node_or_a_node_variable() -> void:
	assert_array(_kinds("@option node(|market)")).is_equal(NODE_TARGETS)
	assert_array(_kinds("@option |node(market)")).is_empty()


func test_draw_names_pools_or_pool_variables() -> void:
	assert_array(_kinds("@draw city, |night")).is_equal(POOL_TARGETS)


func test_a_pool_option_names_pools_but_not_its_parameters() -> void:
	assert_array(_kinds("@option pool(|city, limit: 3)")).is_equal(POOL_TARGETS)
	assert_array(_kinds("@option pool(city, |limit: 3)")).is_empty()
	assert_array(_kinds("@option pool(city, limit: |cap)")).is_equal(NAMES)


func test_a_set_target_can_be_any_name_and_keywords_name_nothing() -> void:
	assert_array(_kinds("@set |energy = 1")).is_equal(NAMES)
	assert_array(_kinds("@|do fade_in()")).is_empty()
	assert_array(_kinds("@|fade_in")).is_empty()


func test_the_name_after_var_in_a_call_is_a_variable() -> void:
	assert_array(_kinds("@do add_to(var |gold, 2)")).is_equal([VARIABLE])
	assert_array(_kinds("@do add_to(2, var |gold)")).is_equal([VARIABLE])


func test_a_call_names_a_function() -> void:
	assert_array(_kinds("@if |bonus(2) > 1: @jump x")).is_equal([FUNCTION])
	assert_array(_kinds("@do |fade_in()")).is_equal([FUNCTION])


func test_a_meta_read_names_a_meta_key_and_its_node() -> void:
	assert_array(_kinds("@set x = .|cost")).is_equal([META_KEY])
	assert_array(_kinds("@set x = |shop.cost")).is_equal(NODE_TARGETS)
	assert_array(_kinds("@set x = shop.|cost")).is_equal([META_KEY])
	assert_str(_resolve("@set x = sh|op.cost").name).is_equal("shop")
	assert_str(_resolve("@set x = shop.co|st").name).is_equal("cost")


func test_a_meta_read_resolves_in_interpolations_and_meta_values() -> void:
	assert_array(_kinds("You pay {shop.|cost}.")).is_equal([META_KEY])
	assert_array(_kinds('@option "Pay {.|cost}": @jump x')).is_equal([META_KEY])
	assert_array(_kinds("toll: |shop.cost + 1", "@node here\n@meta")).is_equal(NODE_TARGETS)


func test_a_bare_name_in_an_expression_can_be_any_name() -> void:
	assert_array(_kinds("@if visited(|market): @jump x")).is_equal(NAMES)


func test_dialogue_text_isnt_code() -> void:
	assert_array(_kinds("Go to |market now.")).is_empty()
	assert_array(_kinds("Guide: Go to |market.")).is_empty()
	assert_array(_kinds('"Old Man": Go to |market.')).is_empty()
	assert_array(_kinds('@option "Visit |market": @jump x')).is_empty()
	assert_array(_kinds("@if x > 1: Go to |market.")).is_empty()


func test_an_interpolation_is_code() -> void:
	assert_array(_kinds("Seen {visited(|market)} times.")).is_equal(NAMES)
	assert_array(_kinds('@option "Seen {visited(|market)}": @jump x')).is_equal(NAMES)
	assert_array(_kinds("Escaped \\{visited(|market)} text.")).is_empty()


func test_an_inline_action_after_a_colon_is_a_line_of_its_own() -> void:
	assert_array(_kinds('@option "Go": @jump |market')).is_equal(NODE_TARGETS)
	assert_array(_kinds("@when x: |Guide: Hi.")).is_equal(SPEAKERS)


func test_comments_and_numbers_resolve_to_nothing() -> void:
	assert_object(_resolve("@jump x # see |market")).is_null()
	assert_object(_resolve("# |market")).is_null()
	assert_object(_resolve("@increase x |2")).is_null()


func test_a_speaker_is_a_character_or_a_character_variable() -> void:
	assert_array(_kinds("|Guide: Hello.")).is_equal(SPEAKERS)
	assert_array(_kinds("  compan|ion : Hello.")).is_equal(SPEAKERS)
	assert_str(_resolve("Gui|de: Hello.").name).is_equal("Guide")


func test_a_one_off_speaker_resolves_only_its_interpolations() -> void:
	assert_array(_kinds('"Old |Man": Hello.')).is_empty()
	assert_array(_kinds('"{|Guide} and Bo": Hello.')).is_equal(NAMES)


func test_a_name_before_a_colon_without_a_space_is_text() -> void:
	assert_array(_kinds("|Guide:Hello.")).is_empty()
	assert_array(_kinds("|Day 3\\: Quiet.")).is_empty()


func _role(line: String, above: String = "@node here") -> WeavlySymbolResolver.Role:
	return _resolve(line, above).role


func test_a_node_header_declares_its_node() -> void:
	assert_array(_kinds("@node |market # stalls", "")).is_equal([NODE])
	assert_int(_role("@node |market", "")).is_equal(WeavlySymbolResolver.Role.DECLARATION)
	assert_int(_role("@node node|", "")).is_equal(WeavlySymbolResolver.Role.DECLARATION)
	assert_object(_resolve("@|node market", "")).is_null()


func test_a_use_is_a_use() -> void:
	assert_int(_role("@jump |market")).is_equal(WeavlySymbolResolver.Role.USE)


func test_meta_keys_and_their_values() -> void:
	var above: String = "@node here\n@meta"
	assert_array(_kinds("|toll: 2", above)).is_equal([META_KEY])
	assert_array(_kinds("pool: city, |night", above)).is_equal([POOL])
	assert_array(_kinds("slot: |bob", above)).is_equal([SLOT])
	assert_array(_kinds("when: visited(|market)", above)).is_equal(NAMES)
	assert_array(_kinds('label_teaser: "Visit |market"', above)).is_empty()


func test_a_pool_or_slot_entry_is_a_membership() -> void:
	var above: String = "@node here\n@meta"
	assert_int(_role("pool: |city", above)).is_equal(WeavlySymbolResolver.Role.MEMBERSHIP)
	assert_int(_role("slot: |bob", above)).is_equal(WeavlySymbolResolver.Role.MEMBERSHIP)
	assert_int(_role("|pool: city", above)).is_equal(WeavlySymbolResolver.Role.USE)
	assert_int(_role("when: visited(|city)", above)).is_equal(WeavlySymbolResolver.Role.USE)


func test_symbols_finds_every_name_on_a_line() -> void:
	var found: Array[WeavlySymbolResolver.Symbol] = WeavlySymbolResolver.symbols(
		"@if visited(market) and gold > 2: Guide paid {gold}.", WeavlyLineScanner.Block.BODY
	)
	(
		assert_array(
			found.map(
				func(s: WeavlySymbolResolver.Symbol) -> String: return "%s:%d" % [s.name, s.column]
			)
		)
		. is_equal(["visited:4", "market:12", "and:20", "gold:24", "gold:46"])
	)


func test_the_meta_block_ends_at_endmeta() -> void:
	assert_array(_kinds("pool: |city", "@node here\n@meta\n@endmeta")).is_empty()


func test_env_only_resolves_name_values() -> void:
	var above: String = "@env"
	assert_array(_kinds("var next: node = |market", above)).is_equal([NODE])
	assert_array(_kinds("var region: pool = |city", above)).is_equal([POOL])
	assert_array(_kinds("var friend: character = |Guide", above)).is_equal([CHARACTER])
	assert_array(_kinds("var next: |node = market", above)).is_empty()
	assert_array(_kinds("func bonus(|points: number): number", above)).is_empty()


func test_env_declarations_declare_their_kind() -> void:
	var above: String = "@env"
	assert_array(_kinds("var |next: node = market", above)).is_equal([VARIABLE])
	assert_array(_kinds("extern var |reputation: number", above)).is_equal([VARIABLE])
	assert_array(_kinds("pool |city", above)).is_equal([POOL])
	assert_array(_kinds("slot |bob", above)).is_equal([SLOT])
	assert_array(_kinds("character |Guide", above)).is_equal([CHARACTER])
	assert_array(_kinds("meta |toll: number = 1", above)).is_equal([META_KEY])
	assert_array(_kinds("func |bonus(points: number): number", above)).is_equal([FUNCTION])
	assert_int(_role("pool |city", above)).is_equal(WeavlySymbolResolver.Role.DECLARATION)


func test_outside_a_node_resolves_to_nothing() -> void:
	assert_object(_resolve("@jump |market", "@node here\n@endnode")).is_null()
