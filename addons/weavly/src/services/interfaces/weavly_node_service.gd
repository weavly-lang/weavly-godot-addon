@abstract class_name WeavlyNodeService
extends WeavlyService

@abstract func has(id: String) -> bool

@abstract
func get_node(id: String, default: WeavlyModel.WeavlyNode = null) -> WeavlyModel.WeavlyNode

@abstract func add_node(node: WeavlyModel.WeavlyNode) -> void

@abstract func get_all_nodes() -> Array[WeavlyModel.WeavlyNode]

@abstract func record_visit(id: String) -> void

@abstract func get_visit_count(id: String) -> int

# Null when the node has no @meta block.
@abstract func get_node_meta(id: String) -> WeavlyModel.NodeMeta

@abstract func add_pool(pool: String) -> void

@abstract func has_pool(pool: String) -> bool

# The nodes whose @meta names the pool, in the order they were added.
@abstract func get_pool_members(pool: String) -> Array[String]

@abstract func get_skip_count(id: String) -> int

@abstract func set_skip_count(id: String, count: int) -> void
