# gdlint:ignore = max-public-methods
extends WeavlyNodeService

const TYPE = "Node"
const UNKNOWN_SAVED_NODE = "Saved counts of node '%s' are skipped because it no longer exists."
const KEY_VISITS = "visits"
const KEY_SKIPS = "skips"

var _nodes: Dictionary[String, WeavlyModel.WeavlyNode] = {}
var _visits: Dictionary[String, int] = {}
var _skips: Dictionary[String, int] = {}
var _pools: Dictionary[String, bool] = {}
var _slots: Dictionary[String, bool] = {}
var _pool_members: Dictionary[String, Array] = {}
var _meta_defaults: Dictionary[String, Variant] = {}


func has(id: String) -> bool:
	return _nodes.has(id)


func add_node(node: WeavlyModel.WeavlyNode) -> void:
	if _nodes.has(node.id):
		push_warning(EXISTING_ID % [TYPE, node.id])
		return
	_nodes[node.id] = node
	if node.meta == null:
		return
	for pool: String in node.meta.pools:
		var members: Array = _pool_members.get_or_add(pool, [])
		members.append(node.id)


func get_node(id: String) -> WeavlyModel.WeavlyNode:
	if not _nodes.has(id):
		push_error(MISSING_ID % [TYPE, id])
	return _nodes.get(id)


func get_all_nodes() -> Array[WeavlyModel.WeavlyNode]:
	return _nodes.values()


func record_visit(id: String) -> void:
	_visits[id] = get_visit_count(id) + 1


func get_visit_count(id: String) -> int:
	return _visits.get(id, 0)


func add_pool(pool: String) -> void:
	_pools[pool] = true


func has_pool(pool: String) -> bool:
	return _pools.has(pool)


func get_all_pools() -> Array[String]:
	var pools: Array[String] = []
	pools.assign(_pools.keys())
	return pools


func add_slot(slot: String) -> void:
	_slots[slot] = true


func has_slot(slot: String) -> bool:
	return _slots.has(slot)


func get_all_slots() -> Array[String]:
	var slots: Array[String] = []
	slots.assign(_slots.keys())
	return slots


func has_name(type: String, name: String) -> bool:
	match type:
		WeavlyDeserializer.TYPE_NODE:
			return has(name)
		WeavlyDeserializer.TYPE_POOL:
			return has_pool(name)
		WeavlyDeserializer.TYPE_SLOT:
			return has_slot(name)
	return false


func add_meta_key(key: String, default: Variant) -> void:
	_meta_defaults[key] = default


func has_meta_key(key: String) -> bool:
	return _meta_defaults.has(key)


func get_meta_default(key: String) -> Variant:
	return _meta_defaults.get(key)


func get_pool_members(pool: String) -> Array[String]:
	var members: Array[String] = []
	members.assign(_pool_members.get(pool, []))
	return members


func get_skip_count(id: String) -> int:
	return _skips.get(id, 0)


func set_skip_count(id: String, count: int) -> void:
	if count == 0:
		_skips.erase(id)
	else:
		_skips[id] = count


func get_state() -> Dictionary:
	return {KEY_VISITS: _visits.duplicate(), KEY_SKIPS: _skips.duplicate()}


func set_state(state: Dictionary) -> void:
	var unknown: Dictionary[String, bool] = {}
	_restore_counts(_visits, state.get(KEY_VISITS, {}), unknown)
	_restore_counts(_skips, state.get(KEY_SKIPS, {}), unknown)


# JSON reads every number as a float, so counts are converted back.
func _restore_counts(
	counts: Dictionary[String, int], saved: Variant, unknown: Dictionary[String, bool]
) -> void:
	counts.clear()
	if saved is not Dictionary:
		return
	for id: String in saved:
		if _nodes.has(id):
			counts[id] = int(saved[id])
		elif not unknown.has(id):
			unknown[id] = true
			push_warning(UNKNOWN_SAVED_NODE % id)
