@abstract class_name WeavlyNodeService
extends WeavlyService

@abstract func has(id: String) -> bool

@abstract func get_node(id: String) -> WeavlyModel.WeavlyNode

@abstract func add_node(node: WeavlyModel.WeavlyNode) -> void

@abstract func get_all_nodes() -> Array[WeavlyModel.WeavlyNode]

@abstract func record_visit(id: String) -> void

@abstract func get_visit_count(id: String) -> int

@abstract func add_pool(pool: String) -> void

@abstract func has_pool(pool: String) -> bool

@abstract func get_all_pools() -> Array[String]

@abstract func add_slot(slot: String) -> void

@abstract func has_slot(slot: String) -> bool

@abstract func get_all_slots() -> Array[String]

# Whether a declared node, pool or slot, by the type's name, has the name.
@abstract func has_name(type: String, name: String) -> bool

# A custom meta key declared in env.json.
@abstract func add_meta_key(key: String, default: Variant) -> void

@abstract func has_meta_key(key: String) -> bool

@abstract func get_meta_default(key: String) -> Variant

# The nodes whose @meta names the pool, in the order they were added.
@abstract func get_pool_members(pool: String) -> Array[String]

@abstract func get_skip_count(id: String) -> int

@abstract func set_skip_count(id: String, count: int) -> void
