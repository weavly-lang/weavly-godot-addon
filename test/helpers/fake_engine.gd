extends WeavlyEngine

const DefaultVariableService = preload(
	"res://addons/weavly/src/services/implementations/default_variable_service.gd"
)

var did_finish: bool = false


func _init() -> void:
	variable_service = DefaultVariableService.new()
	variable_service.initialize(self)


func finish() -> void:
	did_finish = true
