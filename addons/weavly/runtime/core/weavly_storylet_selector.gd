class_name WeavlyStoryletSelector

# How a node would show as an option; the hidden ones are never listed.
enum Display { AVAILABLE, UNAVAILABLE, TEASER, HIDDEN_UNAVAILABLE, HIDDEN_INELIGIBLE }

const UNDECLARED_POOL = "Pool '%s' isn't declared."


class Candidate:
	extends RefCounted
	var id: String
	var slots: Array[String]
	var priority: float
	var display: Display
	# Weighted random key; a higher weight tends to a higher key. Unused without shuffling.
	var order: float
	var source: String
	var line: int

	func is_eligible() -> bool:
		return display != Display.TEASER and display != Display.HIDDEN_INELIGIBLE

	func is_shown() -> bool:
		return display <= Display.TEASER


# Takes up to limit nodes in selection order while their slots are free; updates skip counts.
static func list_pool(
	engine: WeavlyEngine,
	pools: Array,
	limit: int = -1,
	shuffle: bool = true,
	locked: WeavlyEngine.Locked = WeavlyEngine.Locked.SHOW,
) -> Array[String]:
	return _ids(select(engine, pools, limit, shuffle, locked))


# list_pool with each node's display, for pool options.
static func select(
	engine: WeavlyEngine, pools: Array, limit: int, shuffle: bool, locked: WeavlyEngine.Locked
) -> Array[Candidate]:
	var candidates: Array[Candidate] = _rank(engine, pools, shuffle, true)
	var taken: Array[Candidate] = _take(candidates, limit, locked)
	_count_skips(candidates, taken, engine)
	return taken


# The first eligible node in selection order, or empty when there's none; updates skip counts.
# A drawn node isn't an option, so available doesn't apply.
static func draw(engine: WeavlyEngine, pools: Array) -> String:
	var candidates: Array[Candidate] = _rank(engine, pools, true, false)
	var drawn: Array[Candidate] = _take(candidates, 1, WeavlyEngine.Locked.HIDE)
	_count_skips(candidates, drawn, engine)
	return "" if drawn.is_empty() else drawn[0].id


# What list_pool would return now, without changing skip counts or the generator.
static func peek_pool(
	engine: WeavlyEngine,
	pools: Array,
	limit: int = -1,
	shuffle: bool = true,
	locked: WeavlyEngine.Locked = WeavlyEngine.Locked.SHOW,
) -> Array[String]:
	var rng_state: int = engine.rng.state
	var taken: Array[Candidate] = _take(_rank(engine, pools, shuffle, true), limit, locked)
	engine.rng.state = rng_state
	return _ids(taken)


# How the node shows as an option: a false when shows label_teaser, a false available
# label_unavailable, and either is hidden without its label. A failing entry counts as false.
static func display_of(engine: WeavlyEngine, node: WeavlyModel.WeavlyNode) -> Display:
	if not _is_true(WeavlyMetaReader.read_node(engine, node, WeavlyDeserializer.KEY_WHEN)):
		if _has_text(node, WeavlyDeserializer.KEY_LABEL_TEASER):
			return Display.TEASER
		return Display.HIDDEN_INELIGIBLE
	if not _is_true(WeavlyMetaReader.read_node(engine, node, WeavlyDeserializer.KEY_AVAILABLE)):
		if _has_text(node, WeavlyDeserializer.KEY_LABEL_UNAVAILABLE):
			return Display.UNAVAILABLE
		return Display.HIDDEN_UNAVAILABLE
	return Display.AVAILABLE


static func _is_true(value: Variant) -> bool:
	return value is bool and value


static func _has_text(node: WeavlyModel.WeavlyNode, key: String) -> bool:
	return node.meta != null and node.meta.texts.has(key)


static func _ids(candidates: Array[Candidate]) -> Array[String]:
	var ids: Array[String] = []
	for candidate: Candidate in candidates:
		ids.append(candidate.id)
	return ids


# The pools' members that are eligible or shown, highest priority first; within one shuffled
# by weight, or without shuffling in source order. Without options, available isn't read.
static func _rank(
	engine: WeavlyEngine, pools: Array, shuffle: bool, options: bool
) -> Array[Candidate]:
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
		var node: WeavlyModel.WeavlyNode = engine.node_service.get_node(id)
		var candidate: Candidate = _evaluate(node, engine, shuffle, options)
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


# Null when the node is neither eligible nor shown. Weight only matters when shuffling, so
# without shuffling it isn't read.
static func _evaluate(
	node: WeavlyModel.WeavlyNode, engine: WeavlyEngine, shuffle: bool, options: bool
) -> Candidate:
	var display: Display = Display.AVAILABLE
	if options:
		display = display_of(engine, node)
	elif not _is_true(WeavlyMetaReader.read_node(engine, node, WeavlyDeserializer.KEY_WHEN)):
		return null
	if display == Display.HIDDEN_INELIGIBLE:
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
	candidate.display = display
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


# Eligible nodes count: each taken one resets, each other one is skipped once more.
static func _count_skips(
	candidates: Array[Candidate], taken: Array[Candidate], engine: WeavlyEngine
) -> void:
	for candidate: Candidate in candidates:
		if not candidate.is_eligible():
			continue
		var skips: int = 0
		if candidate not in taken:
			skips = engine.node_service.get_skip_count(candidate.id) + 1
		engine.node_service.set_skip_count(candidate.id, skips)


# Locked nodes don't take slots, but a taken slot leaves them out too. With EXTRA they don't
# count toward the limit; with HIDE they're left out.
static func _take(
	candidates: Array[Candidate], limit: int, locked: WeavlyEngine.Locked
) -> Array[Candidate]:
	var taken: Array[Candidate] = []
	var counted: int = 0
	var taken_slots: Dictionary[String, bool] = {}
	for candidate: Candidate in candidates:
		if counted == limit:
			break
		if not candidate.is_shown():
			continue
		var choosable: bool = candidate.display == Display.AVAILABLE
		if not choosable and locked == WeavlyEngine.Locked.HIDE:
			continue
		if candidate.slots.any(func(slot: String) -> bool: return taken_slots.has(slot)):
			continue
		taken.append(candidate)
		if choosable:
			for slot: String in candidate.slots:
				taken_slots[slot] = true
		if choosable or locked == WeavlyEngine.Locked.SHOW:
			counted += 1
	return taken
