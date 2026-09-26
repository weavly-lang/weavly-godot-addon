extends WeavlyUI

var events: Array[String] = []


func _connect_engine() -> void:
	events.append("connect:" + engine.name)


func _disconnect_engine() -> void:
	events.append("disconnect:" + engine.name)
