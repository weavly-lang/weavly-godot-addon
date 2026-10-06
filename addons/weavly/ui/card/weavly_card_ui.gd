class_name WeavlyCardUI
extends WeavlyUI

## Emitted when a deal finds no eligible storylet; the UI hides itself.
signal hand_empty

const DIALOGUE_RUNNING = "Can't deal cards while a dialogue runs."

## The most cards a deal shows.
@export var hand_size: int = 3
@export var card_size: Vector2 = Vector2(240, 320)
@export var outcome_width: float = 520.0

var _pools: Array = []

@onready var _hand: HBoxContainer = %Hand
@onready var _outcome: VBoxContainer = %Outcome
@onready var _continue: Button = %Continue


func _ready() -> void:
	_continue.pressed.connect(_on_continue_pressed)
	WeavlyChoiceList.follow_mouse(_continue)
	clear()
	super()


# Nothing is selected until the first key press, like the other starter UIs.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (is_navigation(event) or event.is_action_pressed(&"ui_accept")):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		return
	if _focus_first():
		get_viewport().set_input_as_handled()


## Deals a hand of up to hand_size storylets from the pools, rendering each as a card.
func deal(pools: Array) -> void:
	if not _can_render(DIALOGUE_RUNNING):
		return
	_pools = pools.duplicate()
	_clear_table()
	var node_ids: Array[String] = engine.list_pool(
		pools, hand_size, true, WeavlyEngine.Locked.HIDE
	)
	if node_ids.is_empty():
		clear()
		hand_empty.emit()
		return
	for node_id: String in node_ids:
		var card: WeavlyCard = _make_card(engine.render(node_id))
		card.custom_minimum_size = card_size
		_hand.add_child(card)
	_hand.visible = true
	visible = true


## Hides the UI and removes every card.
func clear() -> void:
	visible = false
	_pools = []
	_clear_table()


func _engine_signals() -> Array[Array]:
	return [[engine.state_loaded, clear]]


func _on_engine_detached() -> void:
	clear()


func _choose(option: WeavlyModel.Option) -> void:
	if not _can_render_choice(option, DIALOGUE_RUNNING):
		return
	var entries: Array[WeavlyModel.Statement] = engine.render_option(option)
	_clear_table()
	var card: WeavlyCard = _make_card(entries)
	card.custom_minimum_size = Vector2(outcome_width, 0)
	_outcome.add_child(card)
	_outcome.move_child(card, 0)
	_continue.visible = not card.has_choosable()
	_outcome.visible = true


func _on_options_refreshed() -> void:
	super()
	for child: Node in _outcome.get_children():
		if child is WeavlyCard:
			_continue.visible = not child.has_choosable()


func _on_continue_pressed() -> void:
	deal(_pools)


func _make_card(entries: Array[WeavlyModel.Statement]) -> WeavlyCard:
	var card: WeavlyCard = WeavlyCard.new()
	card.show_entries(entries, engine)
	card.chosen.connect(_choose)
	return card


func _focus_first() -> bool:
	for card: WeavlyCard in _cards():
		if card.focus_first():
			return true
	if _continue.is_visible_in_tree():
		_continue.grab_focus()
		return true
	return false


func _cards() -> Array[WeavlyCard]:
	var cards: Array[WeavlyCard] = []
	for container: Container in [_hand, _outcome]:
		for child: Node in container.get_children():
			if child is WeavlyCard:
				cards.append(child)
	return cards


func _clear_table() -> void:
	for card: WeavlyCard in _cards():
		card.get_parent().remove_child(card)
		card.queue_free()
	_hand.visible = false
	_outcome.visible = false
