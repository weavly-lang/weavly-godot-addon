@abstract class_name WeavlyOptionService
extends WeavlyService

signal options_added(options: Array[WeavlyModel.Option])
signal option_chosen(option: WeavlyModel.Option)


@abstract func has_options() -> bool


@abstract func add_options(options: Array[WeavlyModel.Option]) -> void


@abstract func choose_option(option: WeavlyModel.Option) -> void
