extends GdUnitTestSuite

const NONE = WeavlyLineScanner.Block.NONE
const ENV = WeavlyLineScanner.Block.ENV
const BODY = WeavlyLineScanner.Block.BODY
const META = WeavlyLineScanner.Block.META


func _blocks(text: String) -> Array:
	return Array(WeavlyLineScanner.blocks(text.split("\n")))


# The line as one letter per character: t text, c code, s string, # comment.
func _parts(text: String, block: WeavlyLineScanner.Block = BODY) -> String:
	var letters: String = ""
	for part: int in WeavlyLineScanner.parts(text, block):
		letters += "tcs#"[part]
	return letters


# =====================
# blocks
# =====================


func test_an_opening_line_is_outside_its_block_and_a_closing_line_inside() -> void:
	var env: String = "@env\nvar a: number\n@endenv\n"
	var text: String = env + "@node a\n@meta\nwhen: true\n@endmeta\nHi\n@endnode\n"
	assert_array(_blocks(text)).is_equal(
		[NONE, ENV, ENV, NONE, BODY, META, META, BODY, BODY, NONE]
	)


func test_meta_outside_a_node_is_not_a_block() -> void:
	assert_array(_blocks("@meta\nwhen: true\n@endmeta")).is_equal([NONE, NONE, NONE])


func test_a_missing_endnode_doesnt_hide_the_next_node_or_env() -> void:
	assert_array(_blocks("@node a\nHi\n@env\nvar b: flag\n@endenv")).is_equal(
		[NONE, BODY, BODY, ENV, ENV]
	)


func test_block_at_matches_blocks() -> void:
	var lines: PackedStringArray = "@node a\n@meta\nwhen: true\n@endmeta\n@endnode".split("\n")
	var blocks: PackedInt32Array = WeavlyLineScanner.blocks(lines)
	for line: int in lines.size():
		assert_int(WeavlyLineScanner.block_at(lines, line)).is_equal(blocks[line])


func test_node_name_reads_the_declared_name() -> void:
	assert_str(WeavlyLineScanner.node_name("  @node market_2")).is_equal("market_2")
	assert_str(WeavlyLineScanner.node_name("@nodes market")).is_empty()
	assert_str(WeavlyLineScanner.node_name("@node")).is_empty()


func test_directive_is_the_whole_leading_word() -> void:
	assert_str(WeavlyLineScanner.directive("\t@endmeta # done")).is_equal("@endmeta")
	assert_str(WeavlyLineScanner.directive("@envy")).is_equal("@envy")
	assert_str(WeavlyLineScanner.directive("Hi @env")).is_empty()


# =====================
# parts
# =====================


func test_narration_is_text_with_code_inside_braces() -> void:
	assert_str(_parts("a {$b} # c")).is_equal("tttccttttt")


func test_an_escaped_brace_is_text() -> void:
	assert_str(_parts("\\{x}")).is_equal("tttt")


func test_a_directive_line_is_code_up_to_its_comment() -> void:
	assert_str(_parts("@jump a # b")).is_equal("cccccccc###")


func test_a_whole_line_comment_is_a_comment() -> void:
	assert_str(_parts("  # a")).is_equal("tt###")


func test_a_string_is_a_string_with_code_inside_braces() -> void:
	assert_str(_parts('@x "a{b}"')).is_equal("cccsstcts")


func test_inline_text_after_a_colon_is_text_and_an_inline_directive_code() -> void:
	assert_str(_parts('@o "a": b {c}')).is_equal("cccssstttttct")
	assert_str(_parts("@o: @x")).is_equal("ccttcc")


func test_a_colon_inside_brackets_doesnt_end_the_code() -> void:
	assert_str(_parts("@o p(l: 2)")).is_equal("cccccccccc")


func test_a_character_line_is_text() -> void:
	assert_str(_parts(">Bo: {x}")).is_equal("ttttttct")


func test_env_and_meta_lines_are_code() -> void:
	var env: String = 'var a: string = "x" # n'
	assert_str(_parts(env, ENV)).is_equal("cccccccccccccccc" + "sss" + "c" + "###")
	assert_str(_parts("pool: a", META)).is_equal("ccccccc")
