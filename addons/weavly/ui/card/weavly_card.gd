class_name WeavlyCard
extends PanelContainer

signal chosen(option: WeavlyModel.Option)

var _lists: Array[WeavlyChoiceList] = []
var _content: VBoxContainer = VBoxContainer.new()


func _init() -> void:
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)


func show_entries(
	entries: Array[WeavlyModel.Statement], engine: WeavlyEngine, bbcode_enabled: bool
) -> void:
	for entry: WeavlyModel.Statement in entries:
		if entry is WeavlyModel.LineStatement:
			_content.add_child(WeavlyUI.create_line_label(entry, engine, bbcode_enabled))
		elif entry is WeavlyModel.OptionBlock:
			var choices: WeavlyChoiceList = WeavlyChoiceList.new()
			choices.show_options(entry.options)
			choices.chosen.connect(chosen.emit)
			_lists.append(choices)
			_content.add_child(choices)


func has_choosable() -> bool:
	return _lists.any(func(choices: WeavlyChoiceList) -> bool: return choices.has_choosable())


func focus_first() -> bool:
	return _lists.any(func(choices: WeavlyChoiceList) -> bool: return choices.focus_first())
