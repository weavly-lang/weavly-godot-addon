class_name WeavlyStoryletSelector

const UNDECLARED_POOL = "Pool '%s' isn't declared."


class Candidate:
	extends RefCounted
	var id: String
	var slots: Array[String]
	var priority: float
	# Weighted random key; a higher weight tends to a higher key. Unused without shuffling.
	var order: float
	var source: String
	var line: int


# Takes up to limit nodes in selection order while their slots are free; updates skip counts.
static func list_pool(
	engine: WeavlyEngine, pools: Array, limit: int = -1, shuffle: bool = true
) -> Array[String]:
	var candidates: Array[Candidate] = _rank(engine, pools, shuffle)
	var taken: Array[String] = _take(candidates, limit)
	_count_skips(candidates, taken, engine)
	return taken


# The first node in selection order, or empty when none is eligible; updates skip counts.
static func draw(engine: WeavlyEngine, pools: Array) -> String:
	var candidates: Array[Candidate] = _rank(engine, pools, true)
	if candidates.is_empty():
		return ""
	var drawn: Array[String] = [candidates[0].id]
	_count_skips(candidates, drawn, engine)
	return drawn[0]


# What list_pool would return now, without changing skip counts or the generator.
static func peek_pool(
	engine: WeavlyEngine, pools: Array, limit: int = -1, shuffle: bool = true
) -> Array[String]:
	var rng_state: int = engine.rng.state
	var taken: Array[String] = _take(_rank(engine, pools, shuffle), limit)
	engine.rng.state = rng_state
	return taken


# Eligible members of the pools, highest priority first; within one shuffled by weight, or
# without shuffling in source order.
static func _rank(engine: WeavlyEngine, pools: Array, shuffle: bool) -> Array[Candidate]:
	var ids: Array[String] = []
	for pool: Variant in pools:
		var pool_name: String = str(pool)
		if not engine.node_service.has_pool(pool_name):
			engine.report_error(UNDECLARED_POOL % pool_name)
			continue
		for id: String in engine.node_service.get_pool_members(pool_name):
			if id not in ids:
				ids.append(id)

	var candidates: Array[Candidate] = []
	for id: String in ids:
		var candidate: Candidate = _evaluate(engine.node_service.get_node(id), engine, shuffle)
		if candidate != null:
			candidates.append(candidate)

	candidates.sort_custom(_comes_first if shuffle else _comes_first_in_source)
	return candidates


static func _comes_first(a: Candidate, b: Candidate) -> bool:
	return a.priority > b.priority or (a.priority == b.priority and a.order > b.order)


static func _comes_first_in_source(a: Candidate, b: Candidate) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	if a.source != b.source:
		return a.source < b.source
	return a.line < b.line


# Null when the node isn't eligible; a failing entry is reported at its meta line.
# Weight only matters when shuffling, so without shuffling it isn't read.
static func _evaluate(
	node: WeavlyModel.WeavlyNode, engine: WeavlyEngine, shuffle: bool
) -> Candidate:
	var when: Variant = WeavlyMetaReader.read_node(engine, node, WeavlyDeserializer.KEY_WHEN)
	if WeavlyExpressionEvaluator.is_error(when) or not when:
		return null
	var priority: Variant = WeavlyMetaReader.read_node(
		engine, node, WeavlyDeserializer.KEY_PRIORITY
	)
	if WeavlyExpressionEvaluator.is_error(priority):
		return null
	var candidate: Candidate = Candidate.new()
	candidate.id = node.id
	candidate.slots = node.meta.slots
	candidate.priority = priority
	candidate.source = node.source
	candidate.line = node.line
	if shuffle:
		var weight: Variant = WeavlyMetaReader.read_node(
			engine, node, WeavlyDeserializer.KEY_WEIGHT
		)
		if WeavlyExpressionEvaluator.is_error(weight) or weight <= 0.0:
			return null
		candidate.order = pow(engine.rng.randf(), 1.0 / weight)
	return candidate


static func _count_skips(
	candidates: Array[Candidate], taken: Array[String], engine: WeavlyEngine
) -> void:
	for candidate: Candidate in candidates:
		var skips: int = 0
		if candidate.id not in taken:
			skips = engine.node_service.get_skip_count(candidate.id) + 1
		engine.node_service.set_skip_count(candidate.id, skips)


static func _take(candidates: Array[Candidate], limit: int) -> Array[String]:
	var taken: Array[String] = []
	var taken_slots: Dictionary[String, bool] = {}
	for candidate: Candidate in candidates:
		if taken.size() == limit:
			break
		if candidate.slots.any(func(slot: String) -> bool: return taken_slots.has(slot)):
			continue
		taken.append(candidate.id)
		for slot: String in candidate.slots:
			taken_slots[slot] = true
	return taken
