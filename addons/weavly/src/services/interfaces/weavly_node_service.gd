class_name WeavlyNodeService
extends WeavlyService


func has(_id: String) -> bool:
	return false


func get_node(_id: String, default: WeavlyModel.WeavlyNode = null) -> WeavlyModel.WeavlyNode:
	return default


func add_node(_node: WeavlyModel.WeavlyNode) -> void:
	pass


func get_all_nodes() -> Array[WeavlyModel.WeavlyNode]:
	return []
