@abstract class_name WeavlyUI
extends Control

const BOTH_ENGINES = "'%s' has both engine and engine_autoload set, using engine."
const MISSING_AUTOLOAD = "'%s' can't find an autoload named '%s'."
const NOT_AN_ENGINE = "'%s' can't use autoload '%s' because it isn't a WeavlyEngine."
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"
]

## An engine in the same scene. Wins over engine_autoload when both are set.
@export var engine: WeavlyEngine:
	set = set_engine
## The name of an autoloaded engine, looked up when the UI is ready.
@export var engine_autoload: StringName

var _attached: bool = false


func _ready() -> void:
	if engine_autoload != &"":
		if engine != null:
			push_warning(BOTH_ENGINES % name)
		else:
			engine = _find_autoload()
	_attach()


# A paragraph for a line as written, with the speaker's name in bold.
static func create_line_label(
	line: WeavlyModel.LineStatement, engine: WeavlyEngine
) -> RichTextLabel:
	var text: RichTextLabel = create_text_label()
	if line is WeavlyModel.CharacterLine:
		text.push_bold()
		text.add_text(speaker_name(line, engine) + ": ")
		text.pop()
	text.add_text(line.text)
	return text


# An empty paragraph that grows with its text and lets clicks through.
static func create_text_label() -> RichTextLabel:
	var text: RichTextLabel = RichTextLabel.new()
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return text


# The character's display name, or the name as written when there's no such character.
static func speaker_name(line: WeavlyModel.CharacterLine, engine: WeavlyEngine) -> String:
	var character: WeavlyCharacter = find_character(line, engine)
	return character.display_name if character != null else line.name


# Null when no character has the line's name.
static func find_character(
	line: WeavlyModel.CharacterLine, engine: WeavlyEngine
) -> WeavlyCharacter:
	if engine.character_service.has(line.name):
		return engine.character_service.get_character(line.name)
	return null


# Adds a label per line and a choice list per option block, and runs each command.
static func add_entries(
	parent: Node,
	entries: Array[WeavlyModel.Statement],
	engine: WeavlyEngine,
	links: bool = false,
) -> Array[WeavlyChoiceList]:
	var lists: Array[WeavlyChoiceList] = []
	for entry: WeavlyModel.Statement in entries:
		if entry is WeavlyModel.LineStatement:
			parent.add_child(create_line_label(entry, engine))
		elif entry is WeavlyModel.CommandStatement:
			engine.run_command(entry)
		elif entry is WeavlyModel.OptionBlock:
			var choices: WeavlyChoiceList = WeavlyChoiceList.new()
			choices.links = links
			choices.show_options(entry.options)
			lists.append(choices)
			parent.add_child(choices)
	return lists


static func free_children(parent: Node, keep: Node = null) -> void:
	for child: Node in parent.get_children():
		if child != keep:
			parent.remove_child(child)
			child.queue_free()


# False for an empty action or one the project doesn't define.
static func is_pressed(event: InputEvent, action: StringName) -> bool:
	return action != &"" and InputMap.has_action(action) and event.is_action_pressed(action)


static func is_navigation(event: InputEvent) -> bool:
	return NAVIGATION_ACTIONS.any(
		func(action: StringName) -> bool: return event.is_action_pressed(action)
	)


static func is_left_click(event: InputEvent) -> bool:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


# A text as wide as its content, up to max_width, where it wraps.
static func fit_text_width(text: RichTextLabel, max_width: float) -> void:
	var font: Font = text.get_theme_font(&"normal_font")
	var font_size: int = text.get_theme_font_size(&"normal_font_size")
	var width: float = (
		font.get_string_size(text.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	text.custom_minimum_size.x = minf(ceilf(width) + 1.0, max_width)


func set_engine(value: WeavlyEngine) -> void:
	if value == engine:
		return
	_detach()
	engine = value
	if is_node_ready():
		_attach()


# [signal, handler] pairs on the engine and its services, which exist once the engine is ready.
@abstract func _engine_signals() -> Array[Array]


func _on_engine_attached() -> void:
	pass


# Offered options changed in place; every choice list in the UI shows them again.
func _on_options_refreshed() -> void:
	for child: Node in find_children("*", "", true, false):
		if child is WeavlyChoiceList:
			child.refresh()


func _on_engine_detached() -> void:
	pass


# False while detached or while a dialogue runs, which a render can't interrupt.
func _can_render(warning: String) -> bool:
	if not _attached:
		return false
	if engine.is_running():
		push_warning(warning)
		return false
	return true


func _find_autoload() -> WeavlyEngine:
	var node: Node = get_tree().root.get_node_or_null(NodePath(engine_autoload))
	if node == null:
		push_error(MISSING_AUTOLOAD % [name, engine_autoload])
		return null
	if node is not WeavlyEngine:
		push_error(NOT_AN_ENGINE % [name, engine_autoload])
		return null
	return node


func _attach() -> void:
	if engine == null or _attached:
		return
	if not engine.is_node_ready():
		if not engine.ready.is_connected(_attach):
			engine.ready.connect(_attach, CONNECT_ONE_SHOT)
		return
	_attached = true
	for pair: Array in _all_engine_signals():
		(pair[0] as Signal).connect(pair[1])
	_on_engine_attached()


func _detach() -> void:
	if engine == null:
		return
	if engine.ready.is_connected(_attach):
		engine.ready.disconnect(_attach)
	if _attached:
		_attached = false
		for pair: Array in _all_engine_signals():
			(pair[0] as Signal).disconnect(pair[1])
		_on_engine_detached()


func _all_engine_signals() -> Array[Array]:
	var pairs: Array[Array] = _engine_signals()
	pairs.append([engine.options_refreshed, _on_options_refreshed])
	return pairs
