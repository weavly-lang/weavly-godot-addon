extends WeavlyUI

var events: Array[String] = []


func _engine_signals() -> Array[Array]:
	return []


func _on_engine_attached() -> void:
	events.append("connect:" + engine.name)


func _on_engine_detached() -> void:
	events.append("disconnect:" + engine.name)
