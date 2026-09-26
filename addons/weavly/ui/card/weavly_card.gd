class_name WeavlyCard
extends PanelContainer

signal chosen(option: WeavlyModel.Option)

# The option a click on the card chooses; null unless it has exactly one to choose.
var _single: WeavlyModel.Option = null
var _lists: Array[WeavlyChoiceList] = []
var _content: VBoxContainer = VBoxContainer.new()


func _init() -> void:
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	focus_entered.connect(func() -> void: theme_type_variation = &"WeavlyCardSelected")
	focus_exited.connect(func() -> void: theme_type_variation = &"")


func _gui_input(event: InputEvent) -> void:
	if _single == null:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed(&"ui_accept"):
		accept_event()
		chosen.emit(_single)


func show_entries(
	entries: Array[WeavlyModel.Statement], engine: WeavlyEngine, bbcode_enabled: bool
) -> void:
	var choosable: Array[WeavlyModel.Option] = []
	for entry: WeavlyModel.Statement in entries:
		if entry is WeavlyModel.LineStatement:
			_content.add_child(WeavlyUI.create_line_label(entry, engine, bbcode_enabled))
		elif entry is WeavlyModel.OptionBlock:
			var choices: WeavlyChoiceList = WeavlyChoiceList.new()
			choices.show_options(entry.options)
			choices.chosen.connect(chosen.emit)
			choosable.append_array(choices.choosable_options())
			_lists.append(choices)
			_content.add_child(choices)
	if choosable.size() == 1:
		_single = choosable[0]
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(grab_focus)
		for choices: WeavlyChoiceList in _lists:
			choices.make_passive()


func has_choosable() -> bool:
	return (
		_single != null
		or _lists.any(func(choices: WeavlyChoiceList) -> bool: return choices.has_choosable())
	)


# Selects the card, or the first option on a card with several.
func focus_first() -> bool:
	if _single != null:
		grab_focus()
		return true
	for choices: WeavlyChoiceList in _lists:
		if choices.focus_first():
			return true
	return false
