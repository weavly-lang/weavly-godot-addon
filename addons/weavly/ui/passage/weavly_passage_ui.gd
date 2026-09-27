class_name WeavlyPassageUI
extends WeavlyUI

## Emitted for each rendered command, in order; the UI doesn't interpret commands.
signal command_rendered(command: WeavlyModel.CommandStatement)
## Emitted when a passage has no option left to choose.
signal finished

const DIALOGUE_RUNNING = "Can't show a passage while a dialogue runs."

## Keeps earlier passages above the new one instead of replacing them.
@export var append: bool = false

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
	if not (is_navigation(event) or event.is_action_pressed(&"ui_accept")):
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
	if _can_render(DIALOGUE_RUNNING):
		_show(engine.render(node_id), "")


## Hides the UI and removes every passage.
func clear() -> void:
	visible = false
	_current = null
	free_children(_passages)


func _engine_signals() -> Array[Array]:
	return [[engine.state_loaded, clear]]


func _on_engine_detached() -> void:
	clear()


func _choose(option: WeavlyModel.Option) -> void:
	if _can_render(DIALOGUE_RUNNING):
		_show(engine.render_option(option), option.text)


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
	var lists: Array[WeavlyChoiceList] = add_entries(
		_current, entries, engine, command_rendered.emit, true
	)
	var choosable: bool = false
	for choices: WeavlyChoiceList in lists:
		choices.chosen.connect(_choose)
		choosable = choosable or choices.has_choosable()
	visible = true
	_scroll_to_current()
	if not choosable:
		finished.emit()


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
