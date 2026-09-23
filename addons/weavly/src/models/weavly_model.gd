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

	func _init(id: String, body: Array[Statement]):
		self.id = id
		self.body = body


# =====================
# Statements
# =====================


class Statement:
	extends RefCounted
	var line: int = 0

	func _init():
		pass


class LineStatement:
	extends Statement
	var text: String
	var raw_text: String

	func _init(text: String):
		self.text = text
		self.raw_text = text


class NarrationLine:
	extends LineStatement

	func _init(text: String):
		super(text)


class CharacterLine:
	extends LineStatement
	var name: String
	var raw_name: String
	var name_is_id: bool

	func _init(name: String, name_is_id: bool, text: String):
		self.name = name
		self.raw_name = name
		self.name_is_id = name_is_id
		super(text)


class SetStatement:
	extends Statement
	var id: String
	var expression: WeavlyExpression

	func _init(id: String, expression: WeavlyExpression):
		self.id = id
		self.expression = expression


class GotoStatement:
	extends Statement
	var id: String

	func _init(id: String):
		self.id = id


class FinishStatement:
	extends Statement

	func _init():
		pass


class CommandStatement:
	extends Statement
	var id: String
	var args: Array[WeavlyExpression]

	func _init(id: String, args: Array[WeavlyExpression] = []):
		self.id = id
		self.args = args


# =====================
# If Block
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
	var options: Array[Option]

	func _init(options: Array[Option]):
		self.options = options


class Option:
	extends RefCounted
	var condition: WeavlyExpression
	var text: String
	var raw_text: String
	var body: Array[Statement]
	var hint: bool
	var line: int = 0

	func _init(condition: WeavlyExpression, text: String, body: Array[Statement], hint: bool):
		self.condition = condition
		self.text = text
		self.raw_text = text
		self.body = body
		self.hint = hint


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

	func _init():
		pass


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

	func _init():
		pass


class FalseExpression:
	extends WeavlyExpression

	func _init():
		pass


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
	var value: StringName

	func _init(value: StringName):
		self.value = value


# =====================
# Environment
# =====================


class Variable:
	extends RefCounted
	var id: StringName
	var extern: bool = false

	func _init(id: StringName):
		self.id = id

	func get_type_name() -> String:
		return ""


class NumberVariable:
	extends Variable
	var value: float
	var min: Variant
	var max: Variant

	func _init(id: StringName, value: float, min: Variant, max: Variant):
		super._init(id)
		self.value = value
		self.min = min
		self.max = max

	func get_type_name() -> String:
		return "number"


class StringVariable:
	extends Variable
	var value: String

	func _init(id: StringName, value: String):
		super._init(id)
		self.value = value

	func get_type_name() -> String:
		return "string"


class FlagVariable:
	extends Variable
	var value: bool

	func _init(id: StringName, value: bool):
		super._init(id)
		self.value = value

	func get_type_name() -> String:
		return "flag"
