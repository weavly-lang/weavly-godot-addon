extends WeavlyEngine

const DefaultVariableService = preload(
	"res://addons/weavly/src/services/implementations/default_variable_service.gd"
)
const DefaultStatementService = preload(
	"res://addons/weavly/src/services/implementations/default_statement_service.gd"
)

var did_finish: bool = false
var did_next: bool = false
var last_entered_node: String = ""


func _init() -> void:
	variable_service = DefaultVariableService.new()
	variable_service.initialize(self)
	statement_service = DefaultStatementService.new()
	statement_service.initialize(self)


func start(_node_id: String) -> void:
	pass


func enter_node(node_id: String) -> void:
	last_entered_node = node_id


func next() -> void:
	did_next = true


func finish() -> void:
	did_finish = true
