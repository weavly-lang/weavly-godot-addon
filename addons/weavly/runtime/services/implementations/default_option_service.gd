class_name WeavlyDefaultOptionService
extends WeavlyOptionService

var pending_options: Array[WeavlyModel.Option]


func has_options() -> bool:
	return not pending_options.is_empty()


func get_options() -> Array[WeavlyModel.Option]:
	return pending_options.duplicate()


func add_options(options: Array[WeavlyModel.Option]) -> void:
	pending_options = options
	options_added.emit(pending_options)


func clear_options() -> void:
	pending_options = []
