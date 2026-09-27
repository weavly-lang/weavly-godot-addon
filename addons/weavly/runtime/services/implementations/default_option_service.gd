extends WeavlyOptionService

var pending_options: Array[WeavlyModel.Option]


func has_options() -> bool:
	return not pending_options.is_empty()


func add_options(options: Array[WeavlyModel.Option]) -> void:
	var filled: Array[WeavlyModel.Option] = WeavlyTextUtils.fill_options(options, engine)
	if filled.any(func(option: WeavlyModel.Option) -> bool: return not option.hint):
		pending_options = filled
	else:
		# Nothing can be chosen, so the hints wait for next() like a line.
		engine.statement_service.pause()
	options_added.emit(filled)


func clear_options() -> void:
	pending_options = []


func choose_option(option: WeavlyModel.Option) -> void:
	if option.hint:
		push_warning(HINT_CHOSEN % option.text)
		return
	if not pending_options.has(option):
		push_warning(NOT_PENDING % option.text)
		return
	pending_options = []
	engine.statement_service.add_statements(option.body)
	option_chosen.emit(option)
	engine.next()
