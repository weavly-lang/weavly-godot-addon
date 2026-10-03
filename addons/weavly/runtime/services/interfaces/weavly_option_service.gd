@abstract class_name WeavlyOptionService
extends WeavlyService

signal options_added(options: Array[WeavlyModel.Option])

@abstract func has_options() -> bool

@abstract func get_options() -> Array[WeavlyModel.Option]

@abstract func add_options(options: Array[WeavlyModel.Option]) -> void

@abstract func clear_options() -> void
