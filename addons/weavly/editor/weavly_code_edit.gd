@tool
class_name WeavlyCodeEdit
extends CodeEdit

# Takes a line and column and returns the tooltip there; empty shows none.
var tooltip_source: Callable


func _get_tooltip(at_position: Vector2) -> String:
	var at: Vector2i = get_line_column_at_pos(Vector2i(at_position), false)
	if at.y < 0 or not tooltip_source.is_valid():
		return ""
	var line_end: Rect2i = get_rect_at_line_column(at.y, get_line(at.y).length())
	if at_position.y >= line_end.position.y and at_position.x > line_end.end.x:
		return ""
	return tooltip_source.call(at.y, at.x)


# Tooltips show source, so they use the code font.
func _make_custom_tooltip(for_text: String) -> Object:
	var label: Label = Label.new()
	label.text = for_text
	label.add_theme_font_override("font", get_theme_font("font"))
	label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	return label
