extends WeavlyOptionService


var pending_options: Array[WeavlyModel.Option]


func has_options() -> bool:
	return not pending_options.is_empty()


func add_options(options: Array[WeavlyModel.Option]) -> void:
	pending_options = options
	options_added.emit(options)


func choose_option(option: WeavlyModel.Option) -> void:
	pending_options = []
	engine.statement_service.add_statements(option.body)
	option_chosen.emit(option)
	engine.next()
