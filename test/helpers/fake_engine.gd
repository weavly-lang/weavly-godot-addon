extends WeavlyEngine

var did_finish: bool = false
var did_next: bool = false
var holds: int = 0
var last_entered_node: String = ""
var last_detoured_node: String = ""


func _init() -> void:
	variable_service = WeavlyDefaultVariableService.new()
	variable_service.initialize(self)
	statement_service = WeavlyDefaultStatementService.new()
	statement_service.initialize(self)
	node_service = WeavlyDefaultNodeService.new()
	node_service.initialize(self)
	function_service = WeavlyDefaultFunctionService.new()
	function_service.initialize(self)
	option_service = WeavlyDefaultOptionService.new()
	option_service.initialize(self)


func _ready() -> void:
	pass


func start(_node_id: String) -> void:
	pass


func render(_node_id: String) -> Array[WeavlyModel.Statement]:
	return []


func render_option(_option: WeavlyModel.Option) -> Array[WeavlyModel.Statement]:
	return []


func choose(_option: WeavlyModel.Option) -> bool:
	return false


func can_choose(_option: WeavlyModel.Option) -> bool:
	return false


func enter_node(node_id: String) -> void:
	last_entered_node = node_id


func detour(node_id: String) -> void:
	last_detoured_node = node_id


func next() -> void:
	did_next = true


func finish() -> void:
	did_finish = true


func is_running() -> bool:
	return not did_finish


func hold() -> void:
	holds += 1


func release() -> void:
	holds -= 1


func get_state() -> Dictionary:
	return {}


func set_state(_state: Dictionary) -> void:
	pass


func reset_state() -> void:
	pass
