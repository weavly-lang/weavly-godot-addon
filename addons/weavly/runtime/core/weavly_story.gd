# gdlint:ignore = max-public-methods
class_name WeavlyStory
extends RefCounted

# How a value fits a type: FITS, or why it doesn't.
enum Fit { FITS, WRONG_TYPE, UNKNOWN_NAME }

const DUPLICATE_NODE = "Node with id '%s' already exists."

var _variables: Dictionary[String, WeavlyModel.Variable] = {}
var _functions: Dictionary[String, WeavlyModel.Signature] = {}
var _commands: Dictionary[String, WeavlyModel.Signature] = {}
var _nodes: Dictionary[String, WeavlyModel.WeavlyNode] = {}
var _pools: Dictionary[String, bool] = {}
var _pool_members: Dictionary[String, Array] = {}
var _slots: Dictionary[String, bool] = {}
var _meta_defaults: Dictionary[String, Variant] = {}


func add_variable(variable: WeavlyModel.Variable) -> void:
	_variables[variable.id] = variable


# Null when no variable has the id.
func get_variable(id: String) -> WeavlyModel.Variable:
	return _variables.get(id)


func get_variable_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_variables.keys())
	return ids


func add_function(signature: WeavlyModel.Signature) -> void:
	_functions[signature.name] = signature


func get_function(name: String) -> WeavlyModel.Signature:
	return _functions.get(name)


func get_function_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(_functions.keys())
	return names


func add_command(signature: WeavlyModel.Signature) -> void:
	_commands[signature.name] = signature


func get_command(name: String) -> WeavlyModel.Signature:
	return _commands.get(name)


func get_command_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(_commands.keys())
	return names


func add_node(node: WeavlyModel.WeavlyNode) -> void:
	if _nodes.has(node.id):
		push_warning(DUPLICATE_NODE % node.id)
		return
	_nodes[node.id] = node
	if node.meta == null:
		return
	for pool: String in node.meta.pools:
		var members: Array = _pool_members.get_or_add(pool, [])
		members.append(node.id)


func has_node(id: String) -> bool:
	return _nodes.has(id)


func get_node(id: String) -> WeavlyModel.WeavlyNode:
	return _nodes.get(id)


func get_nodes() -> Array[WeavlyModel.WeavlyNode]:
	return _nodes.values()


func add_pool(pool: String) -> void:
	_pools[pool] = true


func has_pool(pool: String) -> bool:
	return _pools.has(pool)


func get_pools() -> Array[String]:
	var pools: Array[String] = []
	pools.assign(_pools.keys())
	return pools


# The nodes whose @meta names the pool, in the order they were added.
func get_pool_members(pool: String) -> Array[String]:
	var members: Array[String] = []
	members.assign(_pool_members.get(pool, []))
	return members


func add_slot(slot: String) -> void:
	_slots[slot] = true


func has_slot(slot: String) -> bool:
	return _slots.has(slot)


func get_slots() -> Array[String]:
	var slots: Array[String] = []
	slots.assign(_slots.keys())
	return slots


func add_meta_key(key: String, default: Variant) -> void:
	_meta_defaults[key] = default


func has_meta_key(key: String) -> bool:
	return _meta_defaults.has(key)


func get_meta_default(key: String) -> Variant:
	return _meta_defaults.get(key)


# Whether a declared node, pool or slot, by the type's name, has the name.
func has_name(type: String, name: String) -> bool:
	match type:
		WeavlyDeserializer.TYPE_NODE:
			return has_node(name)
		WeavlyDeserializer.TYPE_POOL:
			return has_pool(name)
		WeavlyDeserializer.TYPE_SLOT:
			return has_slot(name)
	return false


# Ints count as numbers.
func fit(type: String, value: Variant) -> Fit:
	if value is int:
		value = float(value)
	if typeof(value) != typeof(WeavlyDeserializer.VARIABLE_DEFAULTS[type]):
		return Fit.WRONG_TYPE
	if type != WeavlyDeserializer.TYPE_STRING and value is String and not has_name(type, value):
		return Fit.UNKNOWN_NAME
	return Fit.FITS
