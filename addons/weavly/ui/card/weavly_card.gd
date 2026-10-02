class_name WeavlyCard
extends PanelContainer

signal chosen(option: WeavlyModel.Option)

var _lists: Array[WeavlyChoiceList] = []
var _content: VBoxContainer = VBoxContainer.new()


func _init() -> void:
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)


func show_entries(entries: Array[WeavlyModel.Statement], engine: WeavlyEngine) -> void:
	_lists = WeavlyUI.add_entries(_content, entries, engine)
	for choices: WeavlyChoiceList in _lists:
		choices.chosen.connect(chosen.emit)


func has_choosable() -> bool:
	return _lists.any(func(choices: WeavlyChoiceList) -> bool: return choices.has_choosable())


func focus_first() -> bool:
	return _lists.any(func(choices: WeavlyChoiceList) -> bool: return choices.focus_first())
