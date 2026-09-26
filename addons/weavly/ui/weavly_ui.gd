@abstract class_name WeavlyUI
extends Control

const BOTH_ENGINES = "'%s' has both engine and engine_autoload set, using engine."
const MISSING_AUTOLOAD = "'%s' can't find an autoload named '%s'."
const NOT_AN_ENGINE = "'%s' can't use autoload '%s' because it isn't a WeavlyEngine."

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


# A paragraph for a rendered or executed line, with the speaker's name in bold.
static func create_line_label(
	line: WeavlyModel.LineStatement, engine: WeavlyEngine, bbcode_enabled: bool
) -> RichTextLabel:
	var text: RichTextLabel = RichTextLabel.new()
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.bbcode_enabled = bbcode_enabled
	if line is WeavlyModel.CharacterLine:
		text.push_bold()
		text.add_text(speaker_name(line, engine) + ": ")
		text.pop()
	if bbcode_enabled:
		text.append_text(line.text)
	else:
		text.add_text(line.text)
	return text


# The character's display name, or the name as written when there's no such character.
static func speaker_name(line: WeavlyModel.CharacterLine, engine: WeavlyEngine) -> String:
	if engine.character_service.has(line.name):
		return engine.character_service.get_character(line.name).display_name
	return line.name


func set_engine(value: WeavlyEngine) -> void:
	if value == engine:
		return
	_detach()
	engine = value
	if is_node_ready():
		_attach()


# Connects to the engine's signals and services, which exist once the engine is ready.
@abstract func _connect_engine() -> void

@abstract func _disconnect_engine() -> void


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
	_connect_engine()


func _detach() -> void:
	if engine == null:
		return
	if engine.ready.is_connected(_attach):
		engine.ready.disconnect(_attach)
	if _attached:
		_attached = false
		_disconnect_engine()
