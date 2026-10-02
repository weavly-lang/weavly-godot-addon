class_name WeavlyStoryletSelector

const UNDECLARED_POOL = "Pool '%s' isn't declared."


class Candidate:
	extends RefCounted
	var id: String
	var slots: Array[String]
	var priority: float
	# Weighted random key; a higher weight tends to a higher key.
	var order: float


# Takes up to limit nodes in selection order while their slots are free; updates skip counts.
static func list_pool(engine: WeavlyEngine, pools: Array, limit: int = -1) -> Array[String]:
	var candidates: Array[Candidate] = _rank(engine, pools)
	var taken: Array[String] = _take(candidates, limit)
	_count_skips(candidates, taken, engine)
	return taken


# The first node in selection order, or empty when none is eligible; updates skip counts.
static func draw(engine: WeavlyEngine, pools: Array) -> String:
	var candidates: Array[Candidate] = _rank(engine, pools)
	if candidates.is_empty():
		return ""
	var drawn: Array[String] = [candidates[0].id]
	_count_skips(candidates, drawn, engine)
	return drawn[0]


# What list_pool would return now, without changing skip counts or the generator.
static func peek_pool(engine: WeavlyEngine, pools: Array, limit: int = -1) -> Array[String]:
	var rng_state: int = engine.rng.state
	var taken: Array[String] = _take(_rank(engine, pools), limit)
	engine.rng.state = rng_state
	return taken


# Eligible members of the pools, highest priority first and shuffled by weight within one.
static func _rank(engine: WeavlyEngine, pools: Array) -> Array[Candidate]:
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
		var candidate: Candidate = _evaluate(engine.node_service.get_node(id), engine)
		if candidate != null:
			candidates.append(candidate)

	candidates.sort_custom(
		func(a: Candidate, b: Candidate) -> bool:
			return a.priority > b.priority or (a.priority == b.priority and a.order > b.order)
	)
	return candidates


# Null when the node isn't eligible; a failing entry is reported at its meta line.
static func _evaluate(node: WeavlyModel.WeavlyNode, engine: WeavlyEngine) -> Candidate:
	var when: Variant = WeavlyMetaReader.read_node(engine, node, WeavlyDeserializer.KEY_WHEN)
	if WeavlyExpressionEvaluator.is_error(when) or not when:
		return null
	var priority: Variant = WeavlyMetaReader.read_node(
		engine, node, WeavlyDeserializer.KEY_PRIORITY
	)
	var weight: Variant = WeavlyMetaReader.read_node(engine, node, WeavlyDeserializer.KEY_WEIGHT)
	if WeavlyExpressionEvaluator.is_error(priority) or WeavlyExpressionEvaluator.is_error(weight):
		return null
	if weight <= 0.0:
		return null
	var candidate: Candidate = Candidate.new()
	candidate.id = node.id
	candidate.slots = node.meta.slots
	candidate.priority = priority
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
