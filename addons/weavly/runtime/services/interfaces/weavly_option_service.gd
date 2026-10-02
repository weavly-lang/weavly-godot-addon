@abstract class_name WeavlyOptionService
extends WeavlyService

signal options_added(options: Array[WeavlyModel.Option])
signal option_chosen(option: WeavlyModel.Option)
# Offered options were updated in place: their text, state or hidden flag may have changed.
signal options_refreshed

const NOT_PENDING = "Can't choose option '%s' because it isn't offered right now."
const LOCKED_OPTION = "Can't choose option '%s' because it's locked."

@abstract func has_options() -> bool

@abstract func get_options() -> Array[WeavlyModel.Option]

@abstract func add_options(options: Array[WeavlyModel.Option]) -> void

@abstract func clear_options() -> void

# Checks the option again; a locked one is refused.
@abstract func choose_option(option: WeavlyModel.Option) -> void
