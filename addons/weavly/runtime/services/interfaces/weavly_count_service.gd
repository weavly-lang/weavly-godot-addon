@abstract class_name WeavlyCountService
extends WeavlyService

@abstract func record_visit(id: String) -> void

@abstract func get_visit_count(id: String) -> int

@abstract func get_skip_count(id: String) -> int

@abstract func set_skip_count(id: String, count: int) -> void
