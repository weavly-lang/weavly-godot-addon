extends WeavlyNodeService

const TYPE = "Node"

var _nodes: Dictionary[String, WeavlyModel.WeavlyNode] = {}


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
