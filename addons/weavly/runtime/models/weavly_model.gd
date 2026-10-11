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
	# Every other key, built-in or custom.
	var entries: Dictionary[String, MetaExpression] = {}


class MetaExpression:
	extends RefCounted
	var expression: WeavlyExpression
	var line: int

	func _init(expression: WeavlyExpression, line: int):
		self.expression = expression
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


# The speaker is a CharacterName or a one-off name; character and name are set on filled copies.
class CharacterLine:
	extends LineStatement
	var speaker: WeavlyExpression
	# Empty for a one-off speaker.
	var character: String = ""
	var name: String = ""

	func _init(speaker: WeavlyExpression, segments: Array):
		self.speaker = speaker
		super(segments)


class SetStatement:
	extends Statement
	var id: String
	var expression: WeavlyExpression

	func _init(id: String, expression: WeavlyExpression):
		self.id = id
		self.expression = expression


# Targets are names or variables holding one, as a StringLiteral or an Identifier.
class JumpStatement:
	extends Statement
	var target: WeavlyExpression

	func _init(target: WeavlyExpression):
		self.target = target


class DetourStatement:
	extends Statement
	var target: WeavlyExpression

	func _init(target: WeavlyExpression):
		self.target = target


class FinishStatement:
	extends Statement


class DrawStatement:
	extends Statement
	var pools: Array[WeavlyExpression]

	func _init(pools: Array[WeavlyExpression]):
		self.pools = pools


class DoStatement:
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
	var label: WeavlyExpression
	var body: Array[Statement]

	func _init(condition: WeavlyExpression, label: WeavlyExpression, body: Array[Statement]):
		self.condition = condition
		self.label = label
		self.body = body


class NodeOptionItem:
	extends OptionItem
	var node: WeavlyExpression

	func _init(node: WeavlyExpression):
		self.node = node


# limit is null for no limit.
class PoolOptionItem:
	extends OptionItem
	var pools: Array[WeavlyExpression]
	var limit: WeavlyExpression
	var shuffle: WeavlyExpression
	var locked: WeavlyEngine.Locked

	func _init(
		pools: Array[WeavlyExpression],
		limit: WeavlyExpression,
		shuffle: WeavlyExpression,
		locked: WeavlyEngine.Locked
	):
		self.pools = pools
		self.limit = limit
		self.shuffle = shuffle
		self.locked = locked


# An option as offered; it doesn't change afterwards.
class Option:
	extends RefCounted
	enum State { AVAILABLE, UNAVAILABLE, TEASER }

	var text: String = ""
	var state: State = State.AVAILABLE
	# Empty for an inline option.
	var node_id: String = ""
	# A node option's meta values when offered; the node reads them once chosen.
	var meta: Dictionary = {}
	var line: int = 0
	# The inline option's item and the source of its node; unset for node options.
	var item: InlineOptionItem = null
	var source: String = ""

	func is_choosable() -> bool:
		return state == State.AVAILABLE


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


# A quoted string with {} expressions; segments like a line's.
class TextExpression:
	extends WeavlyExpression
	var segments: Array

	func _init(segments: Array):
		self.segments = segments


# node is the target of visited, visit_count and skip_count, null for other calls.
class Call:
	extends WeavlyExpression
	var name: String
	var node: WeavlyExpression
	var args: Array[WeavlyExpression]

	func _init(name: String, node: WeavlyExpression, args: Array[WeavlyExpression] = []):
		self.name = name
		self.node = node
		self.args = args


class Identifier:
	extends WeavlyExpression
	var value: String

	func _init(value: String):
		self.value = value


# Evaluates to the display name of the character the expression names.
class CharacterName:
	extends WeavlyExpression
	var expression: WeavlyExpression

	func _init(expression: WeavlyExpression):
		self.expression = expression


class MetaCall:
	extends WeavlyExpression
	var node: WeavlyExpression
	var key: String

	func _init(node: WeavlyExpression, key: String):
		self.node = node
		self.key = key


# =====================
# Environment
# =====================


# A declared function; return_type is empty for one without a result.
class Signature:
	extends RefCounted
	const UNDECLARED = "Can't register function '%s' because it isn't declared."
	const WRONG_ARGUMENT_COUNT = (
		"Can't register function '%s' because it takes " + "%d instead of %d arguments."
	)

	var name: String
	var param_types: Array[String]
	var return_type: String

	func _init(name: String, param_types: Array[String], return_type: String = ""):
		self.name = name
		self.param_types = param_types
		self.return_type = return_type

	# Pushes an error and returns false when the callable doesn't fit the name's declaration.
	static func can_register(name: String, callable: Callable, signature: Signature) -> bool:
		if signature == null:
			push_error(UNDECLARED % name)
			return false
		var expected: int = signature.param_types.size()
		var count: int = callable.get_argument_count()
		if count != expected:
			push_error(WRONG_ARGUMENT_COUNT % [name, count, expected])
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


class BoolVariable:
	extends Variable
	var value: bool

	func _init(id: String, value: bool):
		super._init(id)
		self.value = value

	func get_type_name() -> String:
		return "bool"


# A node, pool, slot or character variable; its value names a declared one of that type.
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
