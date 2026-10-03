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


# A node option runs its node like a detour; an inline option's body runs in place.
func choose_option(option: WeavlyModel.Option) -> void:
	if not pending_options.has(option):
		push_warning(NOT_PENDING % option.text)
		return
	WeavlyOptionBuilder.refresh(option, engine)
	if not option.is_choosable():
		push_warning(LOCKED_OPTION % option.text)
		return
	pending_options = []
	option_chosen.emit(option)
	if option.item != null:
		engine.statement_service.add_statements(option.item.body)
		engine.next()
	else:
		engine.snapshot_meta(option.node_id)
		engine.detour(option.node_id)
