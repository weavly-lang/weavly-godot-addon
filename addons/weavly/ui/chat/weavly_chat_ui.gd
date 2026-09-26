class_name WeavlyChatUI
extends WeavlyUI

const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"
]
const DOT_INTERVAL: float = 0.4

## The character id whose lines are the player's own, shown on the right.
@export var player_character: String = ""
## Characters per second the typing indicator waits for before another character's message.
@export var typing_speed: float = 25.0
@export var min_wait: float = 0.6
@export var max_wait: float = 3.0
## Pause before the player's own lines, narration and a reply bar of only hints.
@export var short_wait: float = 0.4
## Shows a waiting message at once, like a click does.
@export var advance_action: StringName = &"ui_accept"
@export var max_bubble_width: float = 280.0
@export var avatar_size: Vector2 = Vector2(36, 36)
## Renders BBCode in lines; injected values like {$name} are parsed too.
@export var bbcode_enabled: bool = false

# The line the UI waits to show, or null while the wait is for a reply bar of only hints.
var _pending: WeavlyModel.LineStatement = null
var _waiting: bool = false
var _wait_left: float = 0.0
var _typing_time: float = 0.0
# Who sent the last bubble on the left, so a run of their messages shows the name only once.
var _last_speaker: String = ""

@onready var _phone: Control = %Phone
@onready var _scroll: ScrollContainer = %Scroll
@onready var _messages: VBoxContainer = %Messages
@onready var _typing: Control = %Typing
@onready var _typing_dots: Label = %TypingDots
@onready var _replies: WeavlyChoiceList = %Replies


func _ready() -> void:
	_replies.chosen.connect(_choose)
	_phone.gui_input.connect(_on_phone_input)
	_scroll.get_v_scroll_bar().changed.connect(_follow_newest)
	clear()
	super()


func _process(delta: float) -> void:
	_typing_time += delta
	_typing_dots.text = "•".repeat(int(_typing_time / DOT_INTERVAL) % 3 + 1)
	_wait_left -= delta
	if _wait_left <= 0.0:
		_end_wait()


# Replies open with nothing selected; the first key press selects one.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var advancing: bool = (
		InputMap.has_action(advance_action) and event.is_action_pressed(advance_action)
	)
	var navigating: bool = NAVIGATION_ACTIONS.any(
		func(action: StringName) -> bool: return event.is_action_pressed(action)
	)
	if _replies.has_choosable() and (advancing or navigating) and _replies.focus_first():
		get_viewport().set_input_as_handled()
	elif advancing and _waiting:
		get_viewport().set_input_as_handled()
		advance()


## Shows a message that's still waiting right away.
func advance() -> void:
	if _waiting:
		_end_wait()


func is_waiting() -> bool:
	return _waiting


## Hides the UI and removes the conversation.
func clear() -> void:
	visible = false
	_stop_waiting()
	_pending = null
	_last_speaker = ""
	_replies.clear()
	for row: Node in _messages.get_children():
		if row != _typing:
			_messages.remove_child(row)
			row.queue_free()


func _connect_engine() -> void:
	engine.state_loaded.connect(clear)
	engine.line_service.executed_narration_line.connect(_receive)
	engine.line_service.executed_character_line.connect(_receive)
	engine.option_service.options_added.connect(_on_options_added)


func _disconnect_engine() -> void:
	engine.state_loaded.disconnect(clear)
	engine.line_service.executed_narration_line.disconnect(_receive)
	engine.line_service.executed_character_line.disconnect(_receive)
	engine.option_service.options_added.disconnect(_on_options_added)
	clear()


func _receive(line: WeavlyModel.LineStatement) -> void:
	visible = true
	_pending = line
	var incoming: bool = line is WeavlyModel.CharacterLine and not _is_player(line)
	_start_wait(_typing_wait(line.text) if incoming else short_wait, incoming)


func _on_options_added(options: Array[WeavlyModel.Option]) -> void:
	visible = true
	_replies.show_options(options)
	if not _replies.has_choosable():
		_start_wait(short_wait, false)


func _choose(option: WeavlyModel.Option) -> void:
	_replies.clear()
	_add_bubble(option.text, null, true)
	engine.option_service.choose_option(option)


func _start_wait(seconds: float, typing: bool) -> void:
	_waiting = true
	_wait_left = seconds
	_typing_time = 0.0
	_typing.visible = typing
	_messages.move_child(_typing, -1)
	set_process(true)


func _stop_waiting() -> void:
	_waiting = false
	_typing.visible = false
	set_process(false)


# Shows the waiting line, or drops a reply bar of only hints, then lets the dialogue go on.
func _end_wait() -> void:
	_stop_waiting()
	if _pending != null:
		var line: WeavlyModel.LineStatement = _pending
		_pending = null
		_add_line(line)
	else:
		_replies.clear()
	engine.next()


func _typing_wait(text: String) -> float:
	if typing_speed <= 0.0:
		return min_wait
	return clampf(text.length() / typing_speed, min_wait, max_wait)


func _is_player(line: WeavlyModel.CharacterLine) -> bool:
	return player_character != "" and line.name == player_character


func _add_line(line: WeavlyModel.LineStatement) -> void:
	if line is WeavlyModel.CharacterLine:
		var character: WeavlyCharacter = null
		if engine.character_service.has(line.name):
			character = engine.character_service.get_character(line.name)
		_add_bubble(line.text, character, _is_player(line), speaker_name(line, engine))
		return
	_last_speaker = ""
	var row: HBoxContainer = _add_row(BoxContainer.ALIGNMENT_CENTER)
	var text: RichTextLabel = _add_text(row, line.text)
	text.theme_type_variation = &"WeavlyChatNarration"
	_fit_width(text)


func _add_bubble(
	text: String, character: WeavlyCharacter, outgoing: bool, speaker: String = ""
) -> void:
	var row: HBoxContainer = _add_row(
		BoxContainer.ALIGNMENT_END if outgoing else BoxContainer.ALIGNMENT_BEGIN
	)
	var continued: bool = not outgoing and speaker == _last_speaker
	_last_speaker = "" if outgoing else speaker
	var chat_character: WeavlyChatCharacter = character as WeavlyChatCharacter
	if not outgoing and chat_character != null and chat_character.avatar != null:
		var avatar: TextureRect = TextureRect.new()
		avatar.texture = null if continued else chat_character.avatar
		avatar.custom_minimum_size = avatar_size
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(avatar)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.theme_type_variation = &"WeavlyChatColumn"
	row.add_child(column)
	if not outgoing and not continued:
		var name_label: Label = Label.new()
		name_label.text = speaker
		name_label.theme_type_variation = &"WeavlyChatName"
		column.add_child(name_label)
	var bubble: PanelContainer = PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.theme_type_variation = &"WeavlyChatOutgoing" if outgoing else &"WeavlyChatIncoming"
	bubble.size_flags_horizontal = (
		Control.SIZE_SHRINK_END if outgoing else Control.SIZE_SHRINK_BEGIN
	)
	column.add_child(bubble)
	if not outgoing and chat_character != null:
		var style: StyleBoxFlat = bubble.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
		if style != null:
			style.bg_color = chat_character.bubble_color
			bubble.add_theme_stylebox_override(&"panel", style)
	_fit_width(_add_text(bubble, text))


func _add_row(alignment: BoxContainer.AlignmentMode) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = alignment
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_messages.add_child(row)
	_messages.move_child(_typing, -1)
	return row


func _add_text(parent: Control, content: String) -> RichTextLabel:
	var text: RichTextLabel = RichTextLabel.new()
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.bbcode_enabled = bbcode_enabled
	parent.add_child(text)
	if bbcode_enabled:
		text.append_text(content)
	else:
		text.add_text(content)
	return text


# A bubble is as wide as its text, up to max_bubble_width, where it wraps.
func _fit_width(text: RichTextLabel) -> void:
	var font: Font = text.get_theme_font(&"normal_font")
	var font_size: int = text.get_theme_font_size(&"normal_font_size")
	var width: float = (
		font.get_string_size(text.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	text.custom_minimum_size.x = minf(ceilf(width) + 1.0, max_bubble_width)


func _on_phone_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _follow_newest() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
