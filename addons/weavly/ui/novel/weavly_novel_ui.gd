class_name WeavlyNovelUI
extends WeavlyUI

const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"
]

## Characters revealed per second; 0 shows each line at once.
@export var characters_per_second: float = 40.0
## Advances like a click does.
@export var advance_action: StringName = &"ui_accept"
## Renders BBCode in lines; injected values like {$name} are parsed too.
@export var bbcode_enabled: bool = false

var _revealing: bool = false
var _revealed: float = 0.0
var _awaiting_choice: bool = false

@onready var _textbox: Control = %Textbox
@onready var _nameplate: Label = %Nameplate
@onready var _text: RichTextLabel = %Text
@onready var _choices: Container = %Choices


func _ready() -> void:
	_clear()
	super()


func _process(delta: float) -> void:
	_revealed += delta * characters_per_second
	if _revealed >= _text.get_total_character_count():
		_complete_reveal()
	else:
		_text.visible_characters = int(_revealed)


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


# Menus open unfocused, so only keyboard and gamepad input shows the focus outline.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var advancing: bool = (
		InputMap.has_action(advance_action) and event.is_action_pressed(advance_action)
	)
	var navigating: bool = NAVIGATION_ACTIONS.any(
		func(action: StringName) -> bool: return event.is_action_pressed(action)
	)
	if _awaiting_choice and (advancing or navigating) and _focus_first_choice():
		get_viewport().set_input_as_handled()
	elif advancing:
		get_viewport().set_input_as_handled()
		advance()


## Completes a line that's still revealing, otherwise continues the dialogue.
func advance() -> void:
	if not _attached or not visible or _awaiting_choice:
		return
	if _revealing:
		_complete_reveal()
	else:
		engine.next()


func is_revealing() -> bool:
	return _revealing


func _connect_engine() -> void:
	engine.started_dialogue.connect(_clear)
	engine.finished_dialogue.connect(_clear)
	engine.state_loaded.connect(_clear)
	engine.line_service.executed_narration_line.connect(_on_narration_line)
	engine.line_service.executed_character_line.connect(_on_character_line)
	engine.option_service.options_added.connect(_on_options_added)


func _disconnect_engine() -> void:
	engine.started_dialogue.disconnect(_clear)
	engine.finished_dialogue.disconnect(_clear)
	engine.state_loaded.disconnect(_clear)
	engine.line_service.executed_narration_line.disconnect(_on_narration_line)
	engine.line_service.executed_character_line.disconnect(_on_character_line)
	engine.option_service.options_added.disconnect(_on_options_added)
	_clear()


func _on_narration_line(line: WeavlyModel.NarrationLine) -> void:
	_nameplate.visible = false
	_show_text(line.text)


func _on_character_line(line: WeavlyModel.CharacterLine) -> void:
	var character: WeavlyCharacter = null
	if engine.character_service.has(line.name):
		character = engine.character_service.get_character(line.name)
	_nameplate.text = character.display_name if character != null else line.name
	if character is WeavlyNovelCharacter:
		_nameplate.add_theme_color_override(&"font_color", character.name_color)
	else:
		_nameplate.remove_theme_color_override(&"font_color")
	_nameplate.visible = true
	_show_text(line.text)


func _on_options_added(options: Array[WeavlyModel.Option]) -> void:
	_clear_choices()
	_awaiting_choice = options.any(
		func(option: WeavlyModel.Option) -> bool: return not option.hint
	)
	for option: WeavlyModel.Option in options:
		var button: Button = Button.new()
		button.text = option.text
		button.disabled = option.hint
		button.pressed.connect(_choose.bind(option))
		_choices.add_child(button)
	visible = true


# False when an option already has focus, so its button handles the key itself.
func _focus_first_choice() -> bool:
	if _choices.get_children().any(func(button: Button) -> bool: return button.has_focus()):
		return false
	for button: Button in _choices.get_children():
		if not button.disabled:
			button.grab_focus()
			return true
	return false


func _choose(option: WeavlyModel.Option) -> void:
	_clear_choices()
	_awaiting_choice = false
	engine.option_service.choose_option(option)


func _show_text(text: String) -> void:
	_clear_choices()
	_awaiting_choice = false
	_text.bbcode_enabled = bbcode_enabled
	_text.text = text
	_textbox.visible = true
	visible = true
	_revealed = 0.0
	if characters_per_second > 0.0 and not text.is_empty():
		_revealing = true
		_text.visible_characters = 0
		set_process(true)
	else:
		_complete_reveal()


func _complete_reveal() -> void:
	_revealing = false
	_text.visible_characters = -1
	set_process(false)


func _clear_choices() -> void:
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _clear() -> void:
	visible = false
	_textbox.visible = false
	_text.text = ""
	_awaiting_choice = false
	_complete_reveal()
	_clear_choices()
