class_name WeavlyOptionBuilder

const UNKNOWN_NODE = "Can't offer node '%s' because it doesn't exist."

const STATES: Dictionary[WeavlyStoryletSelector.Display, WeavlyModel.Option.State] = {
	WeavlyStoryletSelector.Display.AVAILABLE: WeavlyModel.Option.State.AVAILABLE,
	WeavlyStoryletSelector.Display.UNAVAILABLE: WeavlyModel.Option.State.UNAVAILABLE,
	WeavlyStoryletSelector.Display.TEASER: WeavlyModel.Option.State.TEASER,
}
const LABELS: Dictionary[WeavlyStoryletSelector.Display, String] = {
	WeavlyStoryletSelector.Display.AVAILABLE: WeavlyDeserializer.KEY_LABEL,
	WeavlyStoryletSelector.Display.UNAVAILABLE: WeavlyDeserializer.KEY_LABEL_UNAVAILABLE,
	WeavlyStoryletSelector.Display.TEASER: WeavlyDeserializer.KEY_LABEL_TEASER,
}


# The options a block offers, in written order with a pool's nodes where pool(...) stands.
static func offer(
	block: WeavlyModel.OptionBlock, engine: WeavlyEngine
) -> Array[WeavlyModel.Option]:
	var options: Array[WeavlyModel.Option] = []
	for item: WeavlyModel.OptionItem in block.items:
		if item is WeavlyModel.InlineOptionItem:
			var option: WeavlyModel.Option = _offer_inline(item, engine)
			if option != null:
				options.append(option)
		elif item is WeavlyModel.NodeOptionItem:
			var option: WeavlyModel.Option = offer_node(engine, item.node_id)
			if option != null:
				option.line = item.line
				options.append(option)
		elif item is WeavlyModel.PoolOptionItem:
			options.append_array(_offer_pool(item, engine))
	return options


# The node as an option, or null when the display rule hides it.
static func offer_node(engine: WeavlyEngine, node_id: String) -> WeavlyModel.Option:
	if not engine.story.has_node(node_id):
		engine.report_error(UNKNOWN_NODE % node_id)
		return null
	var node: WeavlyModel.WeavlyNode = engine.story.get_node(node_id)
	var display: WeavlyStoryletSelector.Display = WeavlyStoryletSelector.display_of(engine, node)
	if not STATES.has(display):
		return null
	return _node_option(engine, node, display)


# Evaluates the option again and applies the display rule; a hidden option keeps its text.
static func refresh(option: WeavlyModel.Option, engine: WeavlyEngine) -> void:
	if option.item != null:
		option.hidden = not _inline_holds(option, engine)
		if not option.hidden:
			option.text = _inline_text(option, engine)
		return
	if not engine.story.has_node(option.node_id):
		option.hidden = true
		return
	var node: WeavlyModel.WeavlyNode = engine.story.get_node(option.node_id)
	var display: WeavlyStoryletSelector.Display = WeavlyStoryletSelector.display_of(engine, node)
	option.hidden = not STATES.has(display)
	if not option.hidden:
		_show(option, engine, node, display)


static func _node_option(
	engine: WeavlyEngine, node: WeavlyModel.WeavlyNode, display: WeavlyStoryletSelector.Display
) -> WeavlyModel.Option:
	var option: WeavlyModel.Option = WeavlyModel.Option.new()
	option.node_id = node.id
	option.line = node.line
	_show(option, engine, node, display)
	return option


static func _show(
	option: WeavlyModel.Option,
	engine: WeavlyEngine,
	node: WeavlyModel.WeavlyNode,
	display: WeavlyStoryletSelector.Display
) -> void:
	option.state = STATES[display]
	option.text = WeavlyMetaReader.read_node(engine, node, LABELS[display])


static func _offer_inline(
	item: WeavlyModel.InlineOptionItem, engine: WeavlyEngine
) -> WeavlyModel.Option:
	var option: WeavlyModel.Option = WeavlyModel.Option.new()
	option.item = item
	option.line = item.line
	option.source = engine.current_source
	if not _inline_holds(option, engine):
		return null
	option.text = _inline_text(option, engine)
	return option


# Inline options are evaluated at their line in the source of their node.
static func _inline_holds(option: WeavlyModel.Option, engine: WeavlyEngine) -> bool:
	return engine.evaluate_at(
		option.source,
		option.line,
		func() -> bool:
			return WeavlyExpressionEvaluator.evaluate_condition(option.item.condition, engine)
	)


static func _inline_text(option: WeavlyModel.Option, engine: WeavlyEngine) -> String:
	return engine.evaluate_at(
		option.source,
		option.line,
		func() -> String: return WeavlyTextUtils.fill_text(option.item.segments, engine)
	)


# A failing limit or shuffle is reported and the pool offers nothing.
static func _offer_pool(
	item: WeavlyModel.PoolOptionItem, engine: WeavlyEngine
) -> Array[WeavlyModel.Option]:
	var options: Array[WeavlyModel.Option] = []
	engine.current_line = item.line
	var limit: int = -1
	if item.limit != null:
		var value: Variant = WeavlyExpressionEvaluator.evaluate_expression(item.limit, engine)
		if WeavlyExpressionEvaluator.is_error(value):
			return options
		limit = maxi(int(value), 0)
	var shuffle: Variant = WeavlyExpressionEvaluator.evaluate_expression(item.shuffle, engine)
	if WeavlyExpressionEvaluator.is_error(shuffle):
		return options
	var candidates: Array[WeavlyStoryletSelector.Candidate] = WeavlyStoryletSelector.select(
		engine, item.pools, limit, shuffle == true, item.locked
	)
	for candidate: WeavlyStoryletSelector.Candidate in candidates:
		var node: WeavlyModel.WeavlyNode = engine.story.get_node(candidate.id)
		var option: WeavlyModel.Option = _node_option(engine, node, candidate.display)
		option.line = item.line
		options.append(option)
	return options
