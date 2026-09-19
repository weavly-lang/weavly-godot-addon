extends GdUnitTestSuite

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
	_edit.text = line
	var mapping: Dictionary = _highlighter._get_line_syntax_highlighting(0)
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
