extends WeavlyNodeService

const TYPE = "Node"

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
