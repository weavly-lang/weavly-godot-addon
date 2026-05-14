class_name WeavlyOptionService
extends WeavlyService

signal options_added(options: Array[WeavlyModel.Option])
signal option_chosen(option: WeavlyModel.Option)


func has_options() -> bool:
	return false


func add_options(_options: Array[WeavlyModel.Option]) -> void:
	pass


func choose_option(_option: WeavlyModel.Option) -> void:
	pass
