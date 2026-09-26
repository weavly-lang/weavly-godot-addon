class_name WeavlyPassageUI
extends WeavlyUI

## Emitted for each rendered command, in order; the UI doesn't interpret commands.
signal command_rendered(command: WeavlyModel.CommandStatement)
## Emitted when a passage has no option left to choose.
signal finished

const DIALOGUE_RUNNING = "Can't show a passage while a dialogue runs."
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev", &"ui_accept"
]

## Keeps earlier passages above the new one instead of replacing them.
@export var append: bool = false
## Renders BBCode in lines; injected values like {$name} are parsed too.
@export var bbcode_enabled: bool = false

var _current: VBoxContainer = null

@onready var _scroll: ScrollContainer = %Scroll
@onready var _passages: VBoxContainer = %Passages


func _ready() -> void:
	clear()
	super()


# Links open with nothing selected; the first key press selects one.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _current == null:
		return
	if not NAVIGATION_ACTIONS.any(
		func(action: StringName) -> bool: return event.is_action_pressed(action)
	):
		return
	var lists: Array[WeavlyChoiceList] = _choice_lists(_current)
	if lists.any(func(choices: WeavlyChoiceList) -> bool: return choices.has_focus_inside()):
		return
	for choices: WeavlyChoiceList in lists:
		if choices.focus_first():
			get_viewport().set_input_as_handled()
			return


## Renders the node and shows it as a new passage.
func show_passage(node_id: String) -> void:
	if _can_render():
		_show(engine.render(node_id), "")


## Hides the UI and removes every passage.
func clear() -> void:
	visible = false
	_current = null
	for passage: Node in _passages.get_children():
		_passages.remove_child(passage)
		passage.queue_free()


func _connect_engine() -> void:
	engine.state_loaded.connect(clear)


func _disconnect_engine() -> void:
	engine.state_loaded.disconnect(clear)
	clear()


func _choose(option: WeavlyModel.Option) -> void:
	if _can_render():
		_show(engine.render_option(option), option.text)


func _can_render() -> bool:
	if not _attached:
		return false
	if engine.is_running():
		push_warning(DIALOGUE_RUNNING)
		return false
	return true


func _show(entries: Array[WeavlyModel.Statement], chosen_text: String) -> void:
	if append and _current != null:
		for choices: WeavlyChoiceList in _choice_lists(_current):
			_current.remove_child(choices)
			choices.queue_free()
		if chosen_text != "":
			var chosen: Label = Label.new()
			chosen.theme_type_variation = &"WeavlyPassageChosen"
			chosen.text = chosen_text
			_current.add_child(chosen)
	elif not append:
		clear()
	_current = VBoxContainer.new()
	_current.theme_type_variation = &"WeavlyPassage"
	_passages.add_child(_current)
	var choosable: bool = false
	for entry: WeavlyModel.Statement in entries:
		if entry is WeavlyModel.LineStatement:
			_add_line(entry)
		elif entry is WeavlyModel.CommandStatement:
			command_rendered.emit(entry)
		elif entry is WeavlyModel.OptionBlock:
			var choices: WeavlyChoiceList = WeavlyChoiceList.new()
			choices.links = true
			choices.chosen.connect(_choose)
			choices.show_options(entry.options)
			choosable = choosable or choices.has_choosable()
			_current.add_child(choices)
	visible = true
	_scroll_to_current()
	if not choosable:
		finished.emit()


func _add_line(line: WeavlyModel.LineStatement) -> void:
	var text: RichTextLabel = RichTextLabel.new()
	text.fit_content = true
	text.scroll_active = false
	text.bbcode_enabled = bbcode_enabled
	_current.add_child(text)
	if line is WeavlyModel.CharacterLine:
		text.push_bold()
		text.add_text(_speaker_name(line) + ": ")
		text.pop()
	if bbcode_enabled:
		text.append_text(line.text)
	else:
		text.add_text(line.text)


func _speaker_name(line: WeavlyModel.CharacterLine) -> String:
	if engine.character_service.has(line.name):
		return engine.character_service.get_character(line.name).display_name
	return line.name


func _choice_lists(passage: Node) -> Array[WeavlyChoiceList]:
	var lists: Array[WeavlyChoiceList] = []
	for child: Node in passage.get_children():
		if child is WeavlyChoiceList:
			lists.append(child)
	return lists


func _scroll_to_current() -> void:
	if not append:
		_scroll.scroll_vertical = 0
		return
	var passage: Control = _current
	await get_tree().process_frame
	if is_instance_valid(passage) and passage.is_inside_tree():
		_scroll.ensure_control_visible(passage)
