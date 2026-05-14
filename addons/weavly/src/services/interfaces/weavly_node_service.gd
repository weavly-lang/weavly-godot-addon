@abstract class_name WeavlyNodeService
extends WeavlyService


@abstract func has(id: String) -> bool


@abstract func get_node(id: String, default: WeavlyModel.WeavlyNode = null) -> WeavlyModel.WeavlyNode


@abstract func add_node(node: WeavlyModel.WeavlyNode) -> void


@abstract func get_all_nodes() -> Array[WeavlyModel.WeavlyNode]
