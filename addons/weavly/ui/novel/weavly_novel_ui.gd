class_name WeavlyNovelUI
extends WeavlyUI

## Characters revealed per second; 0 shows each line at once.
@export var characters_per_second: float = 40.0
## Advances like a click does.
@export var advance_action: StringName = &"ui_accept"

var _revealing: bool = false
var _revealed: float = 0.0

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


func _unhandled_input(event: InputEvent) -> void:
	_handle_advance_input(event, _choices, advance_action, advance)


## Completes a line that's still revealing, otherwise continues the dialogue.
func advance() -> void:
	if not visible or _choices.has_choosable():
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
		[engine.line_reached, _on_line],
		[engine.options_offered, _on_options_offered],
		[engine.option_chosen, _on_option_chosen],
	]


func _on_engine_detached() -> void:
	_clear()


func _on_line(line: WeavlyModel.LineStatement) -> void:
	if line is WeavlyModel.CharacterLine:
		_show_speaker(line)
	else:
		_nameplate.visible = false
	_show_text(line.text)


func _show_speaker(line: WeavlyModel.CharacterLine) -> void:
	var character: WeavlyCharacter = find_character(line, engine)
	_nameplate.text = speaker_name(line, engine)
	if character is WeavlyNovelCharacter:
		_nameplate.add_theme_color_override(&"font_color", character.name_color)
	else:
		_nameplate.remove_theme_color_override(&"font_color")
	_nameplate.visible = true


func _on_options_offered(options: Array[WeavlyModel.Option]) -> void:
	_choices.show_options(options)
	visible = true


func _on_option_chosen(_option: WeavlyModel.Option) -> void:
	_choices.clear()


func _show_text(text: String) -> void:
	_choices.clear()
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
	_complete_reveal()
	_choices.clear()
