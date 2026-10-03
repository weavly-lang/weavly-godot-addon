class_name WeavlyBubbleUI
extends WeavlyUI

## Advances like a click on the bubble or the bar does.
@export var advance_action: StringName = &"ui_accept"
## Seconds a line stays before the dialogue advances on its own, for barks; 0 waits for the player.
@export var auto_advance: float = 0.0
@export var max_bubble_width: float = 280.0
## The tail's width at the bubble and its length to the speaker.
@export var tail_size: Vector2 = Vector2(18, 14)
## Space a bubble keeps from the edges of the UI.
@export var screen_margin: float = 8.0

var _line: WeavlyModel.LineStatement = null
var _speaker: WeavlySpeaker = null
var _in_bubble: bool = false
var _sized: bool = false
var _tail_tip: Vector2 = Vector2.ZERO
var _awaiting_choice: bool = false
var _auto_left: float = 0.0

@onready var _bubble: PanelContainer = %Bubble
@onready var _bubble_text: RichTextLabel = %BubbleText
@onready var _bar: PanelContainer = %Bar
@onready var _nameplate: Label = %Nameplate
@onready var _bar_text: RichTextLabel = %BarText
@onready var _choices: WeavlyChoiceList = %Choices


func _ready() -> void:
	_choices.chosen.connect(_choose)
	_bubble.gui_input.connect(_on_click)
	_bar.gui_input.connect(_on_click)
	_clear()
	super()


func _process(delta: float) -> void:
	if not visible:
		return
	if _auto_left > 0.0:
		_auto_left -= delta
		if _auto_left <= 0.0:
			advance()
			return
	_follow_speaker()


func _draw() -> void:
	if not _bubble.visible:
		return
	var rect: Rect2 = _bubble.get_rect()
	var style: StyleBoxFlat = _bubble.get_theme_stylebox(&"panel") as StyleBoxFlat
	if style == null or _tail_tip.y <= rect.end.y:
		return
	var half: float = tail_size.x / 2.0
	var base_x: float = clampf(_tail_tip.x, rect.position.x + half * 2.0, rect.end.x - half * 2.0)
	var base_y: float = rect.end.y - 1.0
	draw_colored_polygon(
		[Vector2(base_x - half, base_y), Vector2(base_x + half, base_y), _tail_tip], style.bg_color
	)


# Options open with nothing selected; the first key press selects one.
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


## Continues the dialogue, unless it waits for an option.
func advance() -> void:
	if not visible or _awaiting_choice:
		return
	_auto_left = 0.0
	engine.next()


func _engine_signals() -> Array[Array]:
	return [
		[engine.started_dialogue, _clear],
		[engine.finished_dialogue, _clear],
		[engine.state_loaded, _clear],
		[engine.line_service.executed_narration_line, _on_line],
		[engine.line_service.executed_character_line, _on_line],
		[engine.option_service.options_added, _on_options_added],
	]


func _on_engine_detached() -> void:
	_clear()


func _on_line(line: WeavlyModel.LineStatement) -> void:
	_clear_line()
	visible = true
	_awaiting_choice = false
	_auto_left = auto_advance
	_line = line
	if line is WeavlyModel.CharacterLine:
		_speaker = _find_speaker(line.name)
	if _speaker == null:
		_show_in_bar(line)
		return
	_in_bubble = true
	_set_text(_bubble_text, line.text)
	fit_text_width(_bubble_text, max_bubble_width)
	_sized = false
	_follow_speaker()


func _on_options_added(options: Array[WeavlyModel.Option]) -> void:
	_auto_left = 0.0
	_choices.show_options(options)
	_awaiting_choice = _choices.has_choosable()
	_bar.visible = true
	visible = true


# A block where nothing can be chosen any more lets the player continue past it.
func _on_options_refreshed() -> void:
	super()
	if _choices.get_child_count() > 0:
		_awaiting_choice = _choices.has_choosable()


func _choose(option: WeavlyModel.Option) -> void:
	_choices.clear()
	_awaiting_choice = false
	_bar.visible = _bar_text.visible
	engine.option_service.choose_option(option)


func _show_in_bar(line: WeavlyModel.LineStatement) -> void:
	_nameplate.visible = line is WeavlyModel.CharacterLine
	if line is WeavlyModel.CharacterLine:
		_nameplate.text = speaker_name(line, engine)
	_set_text(_bar_text, line.text)
	_bar_text.visible = true
	_bar.visible = true


# A speaker that leaves the scene mid-line hands its line to the bar.
func _follow_speaker() -> void:
	if not _in_bubble:
		return
	if not is_instance_valid(_speaker) or not _speaker.is_inside_tree():
		_in_bubble = false
		_speaker = null
		_bubble.visible = false
		_show_in_bar(_line)
		queue_redraw()
		return
	_bubble.visible = _speaker.is_on_screen()
	if _bubble.visible and not _sized:
		_size_bubble()
	if _bubble.visible:
		_place_bubble(
			get_global_transform_with_canvas().affine_inverse() * _speaker.get_screen_position()
		)
	queue_redraw()


# The text's height follows its width, and a hidden text isn't measured.
func _size_bubble() -> void:
	_bubble_text.size.x = _bubble_text.custom_minimum_size.x
	_bubble_text.update_minimum_size()
	_bubble.reset_size()
	_sized = true


# Above the point with room for the tail, pushed inside the UI when the point is near an edge.
func _place_bubble(point: Vector2) -> void:
	var bubble_size: Vector2 = _bubble.size
	var area: Rect2 = Rect2(Vector2.ZERO, size).grow(-screen_margin)
	var top_left: Vector2 = point - Vector2(bubble_size.x / 2.0, bubble_size.y + tail_size.y)
	top_left.x = clampf(top_left.x, area.position.x, area.end.x - bubble_size.x)
	top_left.y = clampf(top_left.y, area.position.y, area.end.y - bubble_size.y)
	_bubble.position = top_left
	_tail_tip = point


func _find_speaker(character: String) -> WeavlySpeaker:
	for speaker: WeavlySpeaker in get_tree().get_nodes_in_group(WeavlySpeaker.GROUP):
		if speaker.character == character:
			return speaker
	return null


func _set_text(label: RichTextLabel, content: String) -> void:
	label.clear()
	label.add_text(content)


func _on_click(event: InputEvent) -> void:
	if is_left_click(event):
		get_viewport().set_input_as_handled()
		advance()


func _clear_line() -> void:
	_line = null
	_speaker = null
	_in_bubble = false
	_bubble.visible = false
	_bar.visible = false
	_nameplate.visible = false
	_bar_text.visible = false
	_bar_text.clear()
	_bubble_text.clear()
	_choices.clear()
	queue_redraw()


func _clear() -> void:
	visible = false
	_awaiting_choice = false
	_auto_left = 0.0
	_clear_line()
