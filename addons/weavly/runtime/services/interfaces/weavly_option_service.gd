@abstract class_name WeavlyOptionService
extends WeavlyService

signal options_added(options: Array[WeavlyModel.Option])
signal option_chosen(option: WeavlyModel.Option)

const NOT_PENDING = "Can't choose option '%s' because it isn't offered right now."
const HINT_CHOSEN = "Can't choose option '%s' because it's a hint."

@abstract func has_options() -> bool

@abstract func add_options(options: Array[WeavlyModel.Option]) -> void

@abstract func clear_options() -> void

@abstract func choose_option(option: WeavlyModel.Option) -> void
