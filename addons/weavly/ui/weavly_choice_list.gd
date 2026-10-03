class_name WeavlyChoiceList
extends VBoxContainer

signal chosen(option: WeavlyModel.Option)

## Shows options as LinkButtons instead of Buttons.
@export var links: bool = false

var _options: Array[WeavlyModel.Option] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Locked options show disabled and can't take focus; hidden ones don't show.
func show_options(options: Array[WeavlyModel.Option]) -> void:
	clear()
	_options = options.duplicate()
	for option: WeavlyModel.Option in options:
		var button: BaseButton = _create_button()
		follow_mouse(button)
		button.pressed.connect(func() -> void: chosen.emit(option))
		add_child(button)
		_apply(button, option)


## Shows the options' current text and state, after the engine refreshed them.
func refresh() -> void:
	for i: int in _options.size():
		_apply(get_child(i), _options[i])


func clear() -> void:
	WeavlyUI.free_children(self)
	_options = []


func has_choosable() -> bool:
	return _options.any(func(option: WeavlyModel.Option) -> bool: return option.is_choosable())


func has_focus_inside() -> bool:
	return get_children().any(func(button: BaseButton) -> bool: return button.has_focus())


# False when an option already has focus, so its button handles the key itself.
func focus_first() -> bool:
	if has_focus_inside():
		return false
	for button: BaseButton in get_children():
		if button.visible and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return true
	return false


# Mouse and keys share one selection: hovering selects a control and leaving it deselects it.
static func follow_mouse(control: Control) -> void:
	control.mouse_entered.connect(
		func() -> void:
			if control.focus_mode != Control.FOCUS_NONE:
				control.grab_focus()
	)
	control.mouse_exited.connect(
		func() -> void:
			if control.has_focus():
				control.release_focus()
	)


func _create_button() -> BaseButton:
	if not links:
		var button: Button = Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return button
	var link: LinkButton = LinkButton.new()
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return link


func _apply(button: BaseButton, option: WeavlyModel.Option) -> void:
	var choosable: bool = option.is_choosable()
	button.visible = not option.hidden
	button.disabled = not choosable
	button.focus_mode = Control.FOCUS_ALL if choosable else Control.FOCUS_NONE
	if not choosable and button.has_focus():
		button.release_focus()
	if button is LinkButton:
		(button as LinkButton).text = option.text
		(button as LinkButton).underline = (
			LinkButton.UNDERLINE_MODE_ALWAYS if choosable else LinkButton.UNDERLINE_MODE_NEVER
		)
	else:
		(button as Button).text = option.text
