class_name WeavlyNovelUI
extends WeavlyUI

## Characters revealed per second; 0 shows each line at once.
@export var characters_per_second: float = 40.0
## Advances like a click does.
@export var advance_action: StringName = &"ui_accept"

var _revealing: bool = false
var _revealed: float = 0.0
var _awaiting_choice: bool = false

@onready var _textbox: Control = %Textbox
@onready var _nameplate: Label = %Nameplate
@onready var _text: RichTextLabel = %Text
@onready var _choices: WeavlyChoiceList = %Choices


func _ready() -> void:
	_choices.chosen.connect(_choose)
	_clear()
	super()


func _process(delta: float) -> void:
	_revealed += delta * characters_per_second
	if _revealed >= _text.get_total_character_count():
		_complete_reveal()
	else:
		_text.visible_characters = int(_revealed)


func _gui_input(event: InputEvent) -> void:
	if is_left_click(event):
		accept_event()
		advance()


# Menus open with nothing selected; the first key press selects an option.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var advancing: bool = is_pressed(event, advance_action)
	var navigating: bool = is_navigation(event)
	if _awaiting_choice and (advancing or navigating) and _choices.focus_first():
		get_viewport().set_input_as_handled()
	elif advancing:
		get_viewport().set_input_as_handled()
		advance()


## Completes a line that's still revealing, otherwise continues the dialogue.
func advance() -> void:
	if not visible or _awaiting_choice:
		return
	if _revealing:
		_complete_reveal()
	else:
		engine.next()


func is_revealing() -> bool:
	return _revealing


func _engine_signals() -> Array[Array]:
	return [
		[engine.started_dialogue, _clear],
		[engine.finished_dialogue, _clear],
		[engine.state_loaded, _clear],
		[engine.line_service.executed_narration_line, _on_narration_line],
		[engine.line_service.executed_character_line, _on_character_line],
		[engine.option_service.options_added, _on_options_added],
	]


func _on_engine_detached() -> void:
	_clear()


func _on_narration_line(line: WeavlyModel.NarrationLine) -> void:
	_nameplate.visible = false
	_show_text(line.text)


func _on_character_line(line: WeavlyModel.CharacterLine) -> void:
	var character: WeavlyCharacter = find_character(line, engine)
	_nameplate.text = speaker_name(line, engine)
	if character is WeavlyNovelCharacter:
		_nameplate.add_theme_color_override(&"font_color", character.name_color)
	else:
		_nameplate.remove_theme_color_override(&"font_color")
	_nameplate.visible = true
	_show_text(line.text)


func _on_options_added(options: Array[WeavlyModel.Option]) -> void:
	_choices.show_options(options)
	_awaiting_choice = _choices.has_choosable()
	visible = true


# A block where nothing can be chosen any more lets the player continue past it.
func _on_options_refreshed() -> void:
	super()
	if _choices.get_child_count() > 0:
		_awaiting_choice = _choices.has_choosable()


func _choose(option: WeavlyModel.Option) -> void:
	_choices.clear()
	_awaiting_choice = false
	engine.option_service.choose_option(option)


func _show_text(text: String) -> void:
	_choices.clear()
	_awaiting_choice = false
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


func _clear() -> void:
	visible = false
	_textbox.visible = false
	_text.text = ""
	_awaiting_choice = false
	_complete_reveal()
	_choices.clear()
