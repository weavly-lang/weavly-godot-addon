extends GdUnitTestSuite

const _FIND_TEXT = "alpha beta\nbeta gamma\nBETA\n"

var _code_edit: CodeEdit
var _find_bar: WeavlyFindBar


func before_test() -> void:
	_code_edit = auto_free(CodeEdit.new())
	_code_edit.text = _FIND_TEXT
	add_child(_code_edit)
	_find_bar = auto_free(WeavlyFindBar.new(_code_edit))
	add_child(_find_bar)


func _key(keycode: Key, shift: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.shift_pressed = shift
	return event


func _selection() -> Vector2i:
	return Vector2i(_code_edit.get_selection_from_column(), _code_edit.get_selection_from_line())


func _search_for(text: String) -> void:
	_find_bar._find_field.text = text
	_find_bar._on_find_text_changed(text)


# =====================
# Find (issue #97)
# =====================


func test_open_prefills_with_the_selection() -> void:
	_code_edit.select(1, 5, 1, 10)
	_find_bar.open(false)
	assert_bool(_find_bar.visible).is_true()
	assert_str(_find_bar._find_field.text).is_equal("gamma")


func test_open_ignores_a_multiline_selection() -> void:
	_code_edit.select(0, 0, 1, 4)
	_find_bar.open(false)
	assert_str(_find_bar._find_field.text).is_empty()


func test_typing_selects_the_first_match_and_counts() -> void:
	_find_bar.open(false)
	_search_for("beta")
	assert_bool(_code_edit.has_selection()).is_true()
	assert_that(_selection()).is_equal(Vector2i(6, 0))
	assert_str(_find_bar._find_count.text).is_equal("1 of 3")


func test_find_reports_no_matches() -> void:
	_find_bar.open(false)
	_search_for("delta")
	assert_bool(_code_edit.has_selection()).is_false()
	assert_str(_find_bar._find_count.text).is_equal("No matches")


func test_enter_and_find_next_go_to_the_next_match_and_wrap() -> void:
	_find_bar.open(false)
	_search_for("beta")
	_find_bar._on_find_field_input(_key(KEY_ENTER))
	assert_that(_selection()).is_equal(Vector2i(0, 1))
	_find_bar.find_next()
	assert_that(_selection()).is_equal(Vector2i(0, 2))
	assert_str(_find_bar._find_count.text).is_equal("3 of 3")
	_find_bar._on_find_field_input(_key(KEY_ENTER))
	assert_that(_selection()).is_equal(Vector2i(6, 0))


func test_shift_and_find_previous_go_to_the_previous_match_and_wrap() -> void:
	_find_bar.open(false)
	_search_for("beta")
	_find_bar._on_find_field_input(_key(KEY_ENTER, true))
	assert_that(_selection()).is_equal(Vector2i(0, 2))
	_find_bar.find_previous()
	assert_that(_selection()).is_equal(Vector2i(0, 1))
	_find_bar._on_find_field_input(_key(KEY_ENTER, true))
	assert_that(_selection()).is_equal(Vector2i(6, 0))


func test_escape_closes_the_bar() -> void:
	_find_bar.open(false)
	_search_for("beta")
	_find_bar._on_find_field_input(_key(KEY_ESCAPE))
	assert_bool(_find_bar.visible).is_false()


# =====================
# Replace (issue #104)
# =====================


func test_open_with_replace_shows_the_replace_row() -> void:
	_find_bar.open(true)
	assert_bool(_find_bar._replace_row.visible).is_true()
	_find_bar.open(false)
	assert_bool(_find_bar._replace_row.visible).is_false()


func test_replace_swaps_the_selected_match_and_moves_on() -> void:
	_find_bar.open(true)
	_search_for("beta")
	_find_bar._replace_field.text = "delta"
	_find_bar._on_replace_field_input(_key(KEY_ENTER))
	assert_str(_code_edit.get_line(0)).is_equal("alpha delta")
	assert_that(_selection()).is_equal(Vector2i(0, 1))
	assert_str(_find_bar._find_count.text).is_equal("1 of 2")


func test_replace_without_a_selected_match_only_moves() -> void:
	_find_bar.open(true)
	_search_for("beta")
	_code_edit.deselect()
	_code_edit.set_caret_line(0)
	_code_edit.set_caret_column(0)
	_find_bar._replace_field.text = "delta"
	_find_bar.replace()
	assert_str(_code_edit.text).is_equal(_FIND_TEXT)
	assert_that(_selection()).is_equal(Vector2i(6, 0))


func test_replace_all_is_one_undo_step() -> void:
	_find_bar.open(true)
	_search_for("beta")
	_find_bar._replace_field.text = "delta"
	_find_bar.replace_all()
	assert_str(_code_edit.text).is_equal("alpha delta\ndelta gamma\ndelta\n")
	assert_str(_find_bar._find_count.text).is_equal("No matches")
	_code_edit.undo()
	assert_str(_code_edit.text).is_equal(_FIND_TEXT)


func test_replace_all_reports_the_count() -> void:
	var counts: Array[int] = []
	_find_bar.replaced_all.connect(func(count: int) -> void: counts.append(count))
	_find_bar.open(true)
	_search_for("beta")
	_find_bar._replace_field.text = "delta"
	_find_bar.replace_all()
	assert_array(counts).is_equal([3])


func test_match_case_limits_find_and_replace() -> void:
	_find_bar.open(true)
	_search_for("beta")
	_find_bar._match_case.button_pressed = true
	assert_str(_find_bar._find_count.text).is_equal("1 of 2")
	_find_bar._replace_field.text = "delta"
	_find_bar.replace_all()
	assert_str(_code_edit.text).is_equal("alpha delta\ndelta gamma\nBETA\n")
