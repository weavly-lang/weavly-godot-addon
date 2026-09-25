extends WeavlyOptionService

var pending_options: Array[WeavlyModel.Option]


func has_options() -> bool:
	return false


func add_options(options: Array[WeavlyModel.Option]) -> void:
	var filled: Array[WeavlyModel.Option] = WeavlyTextUtils.fill_options(options, engine)
	pending_options = filled
	options_added.emit(filled)


func clear_options() -> void:
	pending_options = []


func choose_option(option: WeavlyModel.Option) -> void:
	if not pending_options.has(option):
		push_warning(NOT_PENDING % option.text)
		return
	if option.hint:
		push_warning(HINT_CHOSEN % option.text)
		return
	pending_options = []
	engine.statement_service.add_statements(option.body)
	option_chosen.emit(option)
	engine.next()
