class_name WeavlyMetaReader

const UNKNOWN_NODE = "Can't read meta key '%s' of node '%s' because the node doesn't exist."
const UNDECLARED_KEY = "Can't read meta key '%s' of node '%s' because the key isn't declared."
const WRONG_TYPE = "Meta key '%s' of node '%s' can't be of type '%s'."

const BUILT_IN_DEFAULTS: Dictionary[String, Variant] = {
	WeavlyDeserializer.KEY_WHEN: true,
	WeavlyDeserializer.KEY_AVAILABLE: true,
	WeavlyDeserializer.KEY_PRIORITY: 0.0,
	WeavlyDeserializer.KEY_WEIGHT: 1.0,
	WeavlyDeserializer.KEY_LABEL: "",
	WeavlyDeserializer.KEY_LABEL_UNAVAILABLE: "",
	WeavlyDeserializer.KEY_LABEL_TEASER: "",
}


# The node's value for the key, else the key's default; ERROR once a failure is reported.
static func read(engine: WeavlyEngine, node_id: String, key: String) -> Variant:
	if not engine.story.has_node(node_id):
		engine.report_error(UNKNOWN_NODE % [key, node_id])
		return WeavlyExpressionEvaluator.ERROR
	return read_node(engine, engine.story.get_node(node_id), key)


# Every key the node writes, evaluated once; a failing one is left out.
static func snapshot(engine: WeavlyEngine, node: WeavlyModel.WeavlyNode) -> Dictionary:
	var values: Dictionary = {}
	if node.meta == null:
		return values
	for key: String in node.meta.entries:
		var value: Variant = read_node(engine, node, key)
		if not WeavlyExpressionEvaluator.is_error(value):
			values[key] = value
	return values


# Errors point to the entry, in the node's source; the location is restored afterwards.
static func read_node(engine: WeavlyEngine, node: WeavlyModel.WeavlyNode, key: String) -> Variant:
	var meta: WeavlyModel.NodeMeta = node.meta if node.meta != null else WeavlyModel.NodeMeta.new()
	if key == WeavlyDeserializer.KEY_POOL:
		return meta.pools.duplicate()
	if key == WeavlyDeserializer.KEY_SLOT:
		return meta.slots.duplicate()
	var snapshot: Dictionary = engine.get_meta_snapshot(node.id)
	if snapshot.has(key):
		return snapshot[key]
	var default: Variant = BUILT_IN_DEFAULTS.get(key)
	if default == null and engine.story.has_meta_key(key):
		default = engine.story.get_meta_default(key)
	if default == null:
		engine.report_error(UNDECLARED_KEY % [key, node.id])
		return WeavlyExpressionEvaluator.ERROR
	var entry: WeavlyModel.MetaExpression = meta.entries.get(key)
	if entry == null:
		return default
	return engine.evaluate_at(
		node.source,
		entry.line,
		func() -> Variant: return _evaluate(engine, node.id, key, entry, default)
	)


static func _evaluate(
	engine: WeavlyEngine,
	node_id: String,
	key: String,
	entry: WeavlyModel.MetaExpression,
	default: Variant,
) -> Variant:
	var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(entry.expression, engine)
	if not WeavlyExpressionEvaluator.is_error(value) and typeof(value) != typeof(default):
		engine.report_error(WRONG_TYPE % [key, node_id, type_string(typeof(value))])
		return WeavlyExpressionEvaluator.ERROR
	return value
