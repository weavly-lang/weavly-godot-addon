class_name WeavlyStoryletSelector

const UNDECLARED_POOL = "Pool '%s' isn't declared."
const WRONG_NUMBER_TYPE = "Storylet %s can't be of type '%s'."
const DEFAULT_PRIORITY: float = 0.0
const DEFAULT_WEIGHT: float = 1.0


class Candidate:
	extends RefCounted
	var id: String
	var slots: Array[String]
	var priority: float
	# Weighted random key; a higher weight tends to a higher key.
	var order: float


# Takes nodes in selection order while their slots are free; updates skip counts.
static func list_pool(engine: WeavlyEngine, pools: Array) -> Array[String]:
	var candidates: Array[Candidate] = _rank(engine, pools)
	var taken: Array[String] = _take(candidates)
	for candidate: Candidate in candidates:
		var skips: int = 0
		if candidate.id not in taken:
			skips = engine.node_service.get_skip_count(candidate.id) + 1
		engine.node_service.set_skip_count(candidate.id, skips)
	return taken


# What list_pool would return now, without changing skip counts or the generator.
static func peek_pool(engine: WeavlyEngine, pools: Array) -> Array[String]:
	var rng_state: int = engine.rng.state
	var taken: Array[String] = _take(_rank(engine, pools))
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
	var source: String = engine.current_source
	var line: int = engine.current_line
	for id: String in ids:
		var node: WeavlyModel.WeavlyNode = engine.node_service.get_node(id)
		engine.current_source = node.source
		var candidate: Candidate = _evaluate(node, engine)
		if candidate != null:
			candidates.append(candidate)
	engine.current_source = source
	engine.current_line = line

	candidates.sort_custom(
		func(a: Candidate, b: Candidate) -> bool:
			return a.priority > b.priority or (a.priority == b.priority and a.order > b.order)
	)
	return candidates


# Null when the node isn't eligible; a failing entry is reported at its meta line.
static func _evaluate(node: WeavlyModel.WeavlyNode, engine: WeavlyEngine) -> Candidate:
	var meta: WeavlyModel.NodeMeta = node.meta
	if meta.when != null:
		engine.current_line = meta.when.line
		if not WeavlyExpressionEvaluator.evaluate_condition(meta.when.expression, engine):
			return null
	var priority: Variant = _evaluate_number(meta.priority, "priority", DEFAULT_PRIORITY, engine)
	var weight: Variant = _evaluate_number(meta.weight, "weight", DEFAULT_WEIGHT, engine)
	if priority == null or weight == null or weight <= 0.0:
		return null
	var candidate: Candidate = Candidate.new()
	candidate.id = node.id
	candidate.slots = meta.slots
	candidate.priority = priority
	candidate.order = pow(engine.rng.randf(), 1.0 / weight)
	return candidate


static func _evaluate_number(
	entry: WeavlyModel.MetaExpression, name: String, default: float, engine: WeavlyEngine
) -> Variant:
	if entry == null:
		return default
	engine.current_line = entry.line
	var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(entry.expression, engine)
	if WeavlyExpressionEvaluator.is_error(value):
		return null
	if value is not float:
		engine.report_error(WRONG_NUMBER_TYPE % [name, type_string(typeof(value))])
		return null
	return value


static func _take(candidates: Array[Candidate]) -> Array[String]:
	var taken: Array[String] = []
	var taken_slots: Dictionary[String, bool] = {}
	for candidate: Candidate in candidates:
		if candidate.slots.any(func(slot: String) -> bool: return taken_slots.has(slot)):
			continue
		taken.append(candidate.id)
		for slot: String in candidate.slots:
			taken_slots[slot] = true
	return taken
