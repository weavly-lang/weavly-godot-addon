# gdlint:ignore = max-public-methods
extends GdUnitTestSuite

const KEYWORD = WvlSyntaxHighlighter.KEYWORD_COLOR
const FUNCTION = WvlSyntaxHighlighter.FUNCTION_COLOR

var _edit: TextEdit
var _highlighter: WvlSyntaxHighlighter


func before_test() -> void:
	_edit = auto_free(TextEdit.new())
	_highlighter = WvlSyntaxHighlighter.new()
	_edit.syntax_highlighter = _highlighter
	add_child(_edit)


# The highlighter returns {start_index: {"color": ...}}; this expands that back
# into the runs of text painted with one color.
func _spans(line: String, color: Color) -> Array[String]:
	return _spans_at(line, 0, color)


func _spans_at(text: String, line_index: int, color: Color) -> Array[String]:
	_edit.text = text
	var line: String = _edit.get_line(line_index)
	var mapping: Dictionary = _highlighter._get_line_syntax_highlighting(line_index)
	var spans: Array[String] = []
	var current: Color = Color()
	var span: String = ""
	for i in line.length():
		if mapping.has(i):
			if span != "":
				spans.append(span)
				span = ""
			current = mapping[i]["color"]
		if current == color:
			span += line[i]
		elif span != "":
			spans.append(span)
			span = ""
	if span != "":
		spans.append(span)
	return spans


# =====================
# Strings
# =====================


func test_string_is_highlighted() -> void:
	var spans: Array[String] = _spans('@set $s = "hello"', WvlSyntaxHighlighter.STRING_COLOR)
	assert_array(spans).contains_exactly(['"hello"'])


func test_string_with_escaped_quotes_is_highlighted_to_its_end() -> void:
	var spans: Array[String] = _spans(
		'@set $s = "say \\"hi\\""', WvlSyntaxHighlighter.STRING_COLOR
	)
	assert_array(spans).contains_exactly(['"say \\"hi\\""'])


# =====================
# Comments
# =====================


func test_whole_line_comment_is_highlighted() -> void:
	var spans: Array[String] = _spans("# a note", WvlSyntaxHighlighter.COMMENT_COLOR)
	assert_array(spans).contains_exactly(["# a note"])


func test_indented_comment_is_highlighted() -> void:
	var spans: Array[String] = _spans("\t# a note", WvlSyntaxHighlighter.COMMENT_COLOR)
	assert_array(spans).contains_exactly(["# a note"])


func test_comment_after_a_directive_is_highlighted() -> void:
	var spans: Array[String] = _spans("@goto start # a note", WvlSyntaxHighlighter.COMMENT_COLOR)
	assert_array(spans).contains_exactly(["# a note"])


func test_hash_inside_a_string_is_not_a_comment() -> void:
	var line: String = '@set $s = "a # b"'
	assert_array(_spans(line, WvlSyntaxHighlighter.COMMENT_COLOR)).is_empty()
	assert_array(_spans(line, WvlSyntaxHighlighter.STRING_COLOR)).contains_exactly(['"a # b"'])


func test_hash_in_narration_text_is_not_a_comment() -> void:
	var spans: Array[String] = _spans("Hello # b", WvlSyntaxHighlighter.COMMENT_COLOR)
	assert_array(spans).is_empty()


func test_hash_in_a_character_line_is_not_a_comment() -> void:
	var spans: Array[String] = _spans(">Bob: hi # b", WvlSyntaxHighlighter.COMMENT_COLOR)
	assert_array(spans).is_empty()


# =====================
# Numbers
# =====================


func test_number_is_highlighted() -> void:
	var spans: Array[String] = _spans("@inc $score 12.5", WvlSyntaxHighlighter.NUMBER_COLOR)
	assert_array(spans).contains_exactly(["12.5"])


func test_negative_number_includes_the_minus() -> void:
	var spans: Array[String] = _spans("@set $x = -5", WvlSyntaxHighlighter.NUMBER_COLOR)
	assert_array(spans).contains_exactly(["-5"])


func test_subtraction_minus_is_not_part_of_the_number() -> void:
	var spans: Array[String] = _spans("@set $x = $a - 5", WvlSyntaxHighlighter.NUMBER_COLOR)
	assert_array(spans).contains_exactly(["5"])


func test_minus_after_a_number_is_not_part_of_the_number() -> void:
	var spans: Array[String] = _spans("@set $x = 7-5", WvlSyntaxHighlighter.NUMBER_COLOR)
	assert_array(spans).contains_exactly(["7", "5"])


# =====================
# Env blocks
# =====================


func test_extern_and_its_type_are_keywords_in_an_env_block() -> void:
	var text: String = "@env\nextern reputation: number\n@endenv"
	assert_array(_spans_at(text, 1, KEYWORD)).contains_exactly(["extern", "number"])


func test_types_and_flag_values_are_keywords_in_an_env_block() -> void:
	var text: String = '@env\n  name: string = "and"\n  seen: flag = true\n@endenv'
	assert_array(_spans_at(text, 1, KEYWORD)).contains_exactly(["string"])
	assert_array(_spans_at(text, 2, KEYWORD)).contains_exactly(["flag", "true"])


func test_a_variable_named_like_a_type_is_not_a_keyword() -> void:
	var text: String = "@env\nnumber: number = 1\n@endenv"
	assert_array(_spans_at(text, 1, KEYWORD)).contains_exactly(["number"])
	assert_str(_spans_at(text, 1, WvlSyntaxHighlighter.TEXT_COLOR)[0]).is_equal("number: ")


func test_type_names_outside_an_env_block_are_text() -> void:
	var text: String = "@env\nx: number\n@endenv\n@node start\nPhysics: string theory\n@endnode"
	assert_array(_spans_at(text, 4, KEYWORD)).is_empty()


func test_narration_before_any_env_block_is_text() -> void:
	assert_array(_spans("extern: string", KEYWORD)).is_empty()


func test_editing_the_env_line_updates_the_lines_below() -> void:
	_edit.text = "@env\nextern reputation: number\n@endenv"
	var before: Dictionary = _highlighter.get_line_syntax_highlighting(1)
	assert_that(before[0]["color"]).is_equal(KEYWORD)
	_edit.set_line(0, "")
	var after: Dictionary = _highlighter.get_line_syntax_highlighting(1)
	assert_that(after[0]["color"]).is_equal(WvlSyntaxHighlighter.TEXT_COLOR)


# =====================
# Expressions
# =====================


func test_function_calls_on_a_directive_line_are_highlighted() -> void:
	var spans: Array[String] = _spans("@if visited(intro) and clamp($hp, 0, 10) > 2", FUNCTION)
	assert_array(spans).contains_exactly(["visited", "clamp"])


func test_expression_keywords_on_a_directive_line_are_highlighted() -> void:
	var spans: Array[String] = _spans("@set $ok = not $a or $b and true", KEYWORD)
	assert_array(spans).contains_exactly(["not", "or", "and", "true"])


func test_option_and_case_conditions_are_highlighted() -> void:
	assert_array(_spans('@option [visited(shop) or false] "Back"', KEYWORD)).contains_exactly(
		["or", "false"]
	)
	assert_array(_spans("@case [not $seen] 2", KEYWORD)).contains_exactly(["not"])


func test_keywords_in_narration_are_text() -> void:
	assert_array(_spans("You and me, true friends (not really)", KEYWORD)).is_empty()
	assert_array(_spans("Call me(maybe)", FUNCTION)).is_empty()


func test_keywords_in_a_character_line_are_text() -> void:
	assert_array(_spans("> Alice: you and me", KEYWORD)).is_empty()


func test_keywords_in_inline_text_after_a_directive_are_text() -> void:
	assert_array(_spans("@if $a: you and me", KEYWORD)).is_empty()
	var spans: Array[String] = _spans("@if $a: @set $b = true and $c", KEYWORD)
	assert_array(spans).contains_exactly(["true", "and"])


func test_a_directive_or_variable_is_not_a_keyword_or_function() -> void:
	assert_array(_spans("@set $true = $and", KEYWORD)).is_empty()
	assert_array(_spans("@if (visited(x))", FUNCTION)).contains_exactly(["visited"])


func test_strings_and_comments_win_over_keywords_and_functions() -> void:
	assert_array(_spans('@if "and" == $x', KEYWORD)).is_empty()
	assert_array(_spans("@goto x # visited(x) and", FUNCTION)).is_empty()
	assert_array(_spans("@goto x # visited(x) and", KEYWORD)).is_empty()
