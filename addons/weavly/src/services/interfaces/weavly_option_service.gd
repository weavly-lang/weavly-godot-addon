extends WeavlyService
class_name WeavlyOptionService

signal options_added(options: Array[WeavlyModel.Option])
signal option_chosen(option: WeavlyModel.Option)


func has_options() -> bool:
	return false


func add_options(options: Array[WeavlyModel.Option]) -> void:
	pass


func choose_option(option: WeavlyModel.Option) -> void:
	pass
