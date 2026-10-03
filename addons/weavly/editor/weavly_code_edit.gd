@tool
class_name WeavlyCodeEdit
extends CodeEdit


# Tooltips show source, so they use the code font.
func _make_custom_tooltip(for_text: String) -> Object:
	var label: Label = Label.new()
	label.text = for_text
	label.add_theme_font_override("font", get_theme_font("font"))
	label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	return label
