extends WeavlyNodeService

const TYPE = "Node"
const UNKNOWN_SAVED_NODE = "Saved visits to node '%s' are skipped because it no longer exists."

var _nodes: Dictionary[String, WeavlyModel.WeavlyNode] = {}
var _visits: Dictionary[String, int] = {}


func has(id: String) -> bool:
	return _nodes.has(id)


func add_node(node: WeavlyModel.WeavlyNode) -> void:
	if _nodes.has(node.id):
		push_warning(EXISTING_ID % [TYPE, node.id])
		return
	_nodes[node.id] = node


func get_node(id: String, default: WeavlyModel.WeavlyNode = null) -> WeavlyModel.WeavlyNode:
	if not _nodes.has(id):
		push_error(MISSING_ID % [TYPE, id, default])
	return _nodes.get(id, default)


func get_all_nodes() -> Array[WeavlyModel.WeavlyNode]:
	return _nodes.values()


func record_visit(id: String) -> void:
	_visits[id] = get_visit_count(id) + 1


func get_visit_count(id: String) -> int:
	return _visits.get(id, 0)


func get_state() -> Dictionary:
	return _visits.duplicate()


# JSON reads every number as a float, so counts are converted back.
func set_state(state: Dictionary) -> void:
	_visits.clear()
	for id: String in state:
		if not _nodes.has(id):
			push_warning(UNKNOWN_SAVED_NODE % id)
			continue
		_visits[id] = int(state[id])
