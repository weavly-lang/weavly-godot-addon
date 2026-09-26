class_name WeavlyChoiceList
extends VBoxContainer

signal chosen(option: WeavlyModel.Option)

## Shows options as LinkButtons instead of Buttons.
@export var links: bool = false

var _options: Array[WeavlyModel.Option] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Hovering selects an option like the keys do, so mouse and keys share one selection.
func show_options(options: Array[WeavlyModel.Option]) -> void:
	clear()
	_options = options.duplicate()
	for option: WeavlyModel.Option in options:
		var button: BaseButton = _create_button(option)
		button.disabled = option.hint
		if option.hint:
			button.focus_mode = Control.FOCUS_NONE
		else:
			button.focus_mode = Control.FOCUS_ALL
			button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(func() -> void: chosen.emit(option))
		add_child(button)


func clear() -> void:
	_options = []
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func has_choosable() -> bool:
	return get_children().any(
		func(button: BaseButton) -> bool: return button.focus_mode != Control.FOCUS_NONE
	)


func choosable_options() -> Array[WeavlyModel.Option]:
	return _options.filter(func(option: WeavlyModel.Option) -> bool: return not option.hint)


# Leaves selection and clicks to a parent that chooses for the list, like a clickable card.
func make_passive() -> void:
	for button: BaseButton in get_children():
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func has_focus_inside() -> bool:
	return get_children().any(func(button: BaseButton) -> bool: return button.has_focus())


# False when an option already has focus, so its button handles the key itself.
func focus_first() -> bool:
	if has_focus_inside():
		return false
	for button: BaseButton in get_children():
		if button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return true
	return false


func _create_button(option: WeavlyModel.Option) -> BaseButton:
	if not links:
		var button: Button = Button.new()
		button.text = option.text
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return button
	var link: LinkButton = LinkButton.new()
	link.text = option.text
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if option.hint:
		link.underline = LinkButton.UNDERLINE_MODE_NEVER
	return link
