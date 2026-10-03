class_name WeavlyModel
extends RefCounted

# =====================
# Nodes
# =====================


class WeavlyNode:
	extends RefCounted
	var id: String
	var body: Array[Statement]
	var source: String = ""
	var line: int = 0
	# Null for a node without an @meta block.
	var meta: NodeMeta = null

	func _init(id: String, body: Array[Statement]):
		self.id = id
		self.body = body


# A key that isn't written uses its default.
class NodeMeta:
	extends RefCounted
	var pools: Array[String] = []
	var slots: Array[String] = []
	# Every other key, built-in or custom, except the label keys.
	var entries: Dictionary[String, MetaExpression] = {}
	var texts: Dictionary[String, MetaText] = {}


class MetaExpression:
	extends RefCounted
	var expression: WeavlyExpression
	var line: int

	func _init(expression: WeavlyExpression, line: int):
		self.expression = expression
		self.line = line


# A label key: segments like a line's.
class MetaText:
	extends RefCounted
	var segments: Array
	var line: int

	func _init(segments: Array, line: int):
		self.segments = segments
		self.line = line


# =====================
# Statements
# =====================


class Statement:
	extends RefCounted
	var line: int = 0


# Segments are plain Strings and WeavlyExpressions; text is set on filled copies.
class LineStatement:
	extends Statement
	var segments: Array
	var text: String = ""

	func _init(segments: Array):
		self.segments = segments


class NarrationLine:
	extends LineStatement


class CharacterLine:
	extends LineStatement
	var name: String
	var raw_name: String
	var name_is_id: bool

	func _init(name: String, name_is_id: bool, segments: Array):
		self.name = name
		self.raw_name = name
		self.name_is_id = name_is_id
		super(segments)


class SetStatement:
	extends Statement
	var id: String
	var expression: WeavlyExpression

	func _init(id: String, expression: WeavlyExpression):
		self.id = id
		self.expression = expression


class JumpStatement:
	extends Statement
	var id: String

	func _init(id: String):
		self.id = id


class DetourStatement:
	extends Statement
	var id: String

	func _init(id: String):
		self.id = id


class FinishStatement:
	extends Statement


class DrawStatement:
	extends Statement
	var pools: Array[String]

	func _init(pools: Array[String]):
		self.pools = pools


class CommandStatement:
	extends Statement
	var id: String
	var args: Array[WeavlyExpression]
	# The evaluated args, set on filled copies.
	var values: Array = []

	func _init(id: String, args: Array[WeavlyExpression] = []):
		self.id = id
		self.args = args


# =====================
# Match Block
# =====================

enum MatchModifier { FIRST, LAST, ALL }


class MatchBlock:
	extends Statement
	var modifier: MatchModifier
	var cases: Array[WhenCase]

	func _init(modifier: MatchModifier, cases: Array[WhenCase]):
		self.modifier = modifier
		self.cases = cases


class WhenCase:
	extends RefCounted
	var condition: WeavlyExpression
	var body: Array[Statement]
	var line: int = 0

	func _init(condition: WeavlyExpression, body: Array[Statement]):
		self.condition = condition
		self.body = body


# =====================
# Option Block
# =====================


class OptionBlock:
	extends Statement
	var items: Array[OptionItem]
	# The offered options, set on rendered copies.
	var options: Array[Option] = []

	func _init(items: Array[OptionItem]):
		self.items = items


class OptionItem:
	extends RefCounted
	var line: int = 0


# An anonymous node: no id, meta, visits or once.
class InlineOptionItem:
	extends OptionItem
	var condition: WeavlyExpression
	var segments: Array
	var body: Array[Statement]

	func _init(condition: WeavlyExpression, segments: Array, body: Array[Statement]):
		self.condition = condition
		self.segments = segments
		self.body = body


class NodeOptionItem:
	extends OptionItem
	var node_id: String

	func _init(node_id: String):
		self.node_id = node_id


# limit is null for no limit.
class PoolOptionItem:
	extends OptionItem
	var pools: Array[String]
	var limit: WeavlyExpression
	var shuffle: WeavlyExpression
	var locked: WeavlyEngine.Locked

	func _init(
		pools: Array[String],
		limit: WeavlyExpression,
		shuffle: WeavlyExpression,
		locked: WeavlyEngine.Locked
	):
		self.pools = pools
		self.limit = limit
		self.shuffle = shuffle
		self.locked = locked


# An option as offered; a refresh updates it in place.
class Option:
	extends RefCounted
	enum State { AVAILABLE, UNAVAILABLE, TEASER }

	var text: String = ""
	var state: State = State.AVAILABLE
	# Set once a refresh finds the display rule hides it.
	var hidden: bool = false
	# Empty for an inline option.
	var node_id: String = ""
	var line: int = 0
	# The inline option's item and the source of its node; unset for node options.
	var item: InlineOptionItem = null
	var source: String = ""

	func is_choosable() -> bool:
		return not hidden and state == State.AVAILABLE


# =====================
# Random Block
# =====================


class RandomBlock:
	extends Statement
	var cases: Array[RandomCase]

	func _init(cases: Array[RandomCase]):
		self.cases = cases


class RandomCase:
	extends RefCounted
	var condition: WeavlyExpression
	var weight: WeavlyExpression
	var body: Array[Statement]
	var line: int = 0

	func _init(
		condition: WeavlyExpression,
		weight: WeavlyExpression,
		body: Array[Statement],
	):
		self.condition = condition
		self.weight = weight
		self.body = body


# =====================
# Expressions
# =====================


class WeavlyExpression:
	extends RefCounted


class UnaryExpression:
	extends WeavlyExpression
	var op: String
	var expression: WeavlyExpression

	func _init(op: String, expression: WeavlyExpression):
		self.op = op
		self.expression = expression


class BinaryExpression:
	extends WeavlyExpression
	var op: String
	var left: WeavlyExpression
	var right: WeavlyExpression

	func _init(op: String, left: WeavlyExpression, right: WeavlyExpression):
		self.op = op
		self.left = left
		self.right = right


class TrueExpression:
	extends WeavlyExpression


class FalseExpression:
	extends WeavlyExpression


class Number:
	extends WeavlyExpression
	var value: float

	func _init(value: float):
		self.value = value


class StringLiteral:
	extends WeavlyExpression
	var value: String

	func _init(value: String):
		self.value = value


class Call:
	extends WeavlyExpression
	var name: String
	var node_id: String
	var args: Array[WeavlyExpression]

	func _init(name: String, node_id: String, args: Array[WeavlyExpression] = []):
		self.name = name
		self.node_id = node_id
		self.args = args


class Identifier:
	extends WeavlyExpression
	var value: String

	func _init(value: String):
		self.value = value


class MetaCall:
	extends WeavlyExpression
	var node_id: String
	var key: String

	func _init(node_id: String, key: String):
		self.node_id = node_id
		self.key = key


# =====================
# Environment
# =====================


# A declared function or command; a command has no return type.
class Signature:
	extends RefCounted
	const UNDECLARED = "Can't register %s '%s' because it isn't declared."
	const WRONG_ARGUMENT_COUNT = "Can't register %s '%s' because it takes %d instead of %d arguments."

	var name: String
	var param_types: Array[String]
	var return_type: String

	func _init(name: String, param_types: Array[String], return_type: String = ""):
		self.name = name
		self.param_types = param_types
		self.return_type = return_type

	# Pushes an error and returns false when the callable doesn't fit a declaration of the name.
	static func can_register(
		kind: String, name: String, callable: Callable, declarations: Dictionary
	) -> bool:
		if not declarations.has(name):
			push_error(UNDECLARED % [kind, name])
			return false
		var expected: int = (declarations[name] as Signature).param_types.size()
		var count: int = callable.get_argument_count()
		if count != expected:
			push_error(WRONG_ARGUMENT_COUNT % [kind, name, count, expected])
			return false
		return true


class Variable:
	extends RefCounted
	var id: String
	var extern: bool = false

	func _init(id: String):
		self.id = id

	func get_type_name() -> String:
		return ""


class NumberVariable:
	extends Variable
	var value: float
	var min: Variant
	var max: Variant

	func _init(id: String, value: float, min: Variant, max: Variant):
		super._init(id)
		self.value = value
		self.min = min
		self.max = max

	func get_type_name() -> String:
		return "number"

	func clamp_value(number: float) -> float:
		if min != null:
			number = maxf(min, number)
		if max != null:
			number = minf(max, number)
		return number


class StringVariable:
	extends Variable
	var value: String

	func _init(id: String, value: String):
		super._init(id)
		self.value = value

	func get_type_name() -> String:
		return "string"


class FlagVariable:
	extends Variable
	var value: bool

	func _init(id: String, value: bool):
		super._init(id)
		self.value = value

	func get_type_name() -> String:
		return "flag"


# A node, pool or slot variable; its value names a declared one of that type.
class NameVariable:
	extends Variable
	var type: String
	var value: String

	func _init(id: String, type: String, value: String):
		super._init(id)
		self.type = type
		self.value = value

	func get_type_name() -> String:
		return type
