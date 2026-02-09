extends WeavlyService
class_name WeavlyNodeService


func has(id: String) -> bool:
	return false


func get_node(id: String, default: WeavlyModel.WeavlyNode = null) -> WeavlyModel.WeavlyNode:
	return default


func add_node(node: WeavlyModel.WeavlyNode) -> void:
	pass


func get_all_nodes() -> Array[WeavlyModel.WeavlyNode]:
	return []
