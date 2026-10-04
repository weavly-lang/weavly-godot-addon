class_name WeavlyDefaultCountService
extends WeavlyCountService

const UNKNOWN_SAVED_NODE = "Saved counts of node '%s' are skipped because it no longer exists."
const KEY_VISITS = "visits"
const KEY_SKIPS = "skips"

var _visits: Dictionary[String, int] = {}
var _skips: Dictionary[String, int] = {}


func record_visit(id: String) -> void:
	_visits[id] = get_visit_count(id) + 1


func get_visit_count(id: String) -> int:
	return _visits.get(id, 0)


func get_skip_count(id: String) -> int:
	return _skips.get(id, 0)


func set_skip_count(id: String, count: int) -> void:
	if count == 0:
		_skips.erase(id)
	else:
		_skips[id] = count


func get_state() -> Dictionary:
	return {KEY_VISITS: _visits.duplicate(), KEY_SKIPS: _skips.duplicate()}


func set_state(state: Dictionary) -> void:
	var unknown: Dictionary[String, bool] = {}
	_restore_counts(_visits, state.get(KEY_VISITS, {}), unknown)
	_restore_counts(_skips, state.get(KEY_SKIPS, {}), unknown)


# JSON reads every number as a float, so counts are converted back.
func _restore_counts(
	counts: Dictionary[String, int], saved: Variant, unknown: Dictionary[String, bool]
) -> void:
	counts.clear()
	if saved is not Dictionary:
		return
	for id: String in saved:
		if engine.story.has_node(id):
			counts[id] = int(saved[id])
		elif not unknown.has(id):
			unknown[id] = true
			push_warning(UNKNOWN_SAVED_NODE % id)
