# gdlint:ignore = max-public-methods
extends WeavlyTestSuite

# Rendering and choosing against the compiler-built fixture in render/src/render.wvl.

const FIXTURE = "res://test/fixtures/integration/render/build"

var _events: Array[String]


func before_test() -> void:
	_events = []


func _make_engine() -> WeavlyDefaultEngine:
	var engine: WeavlyDefaultEngine = WeavlyDefaultEngine.new()
	engine.dialogue_path = FIXTURE
	engine.video_path = FIXTURE
	engine.image_path = FIXTURE
	engine.character_path = FIXTURE
	engine.variable_path = FIXTURE
	add_child(auto_free(engine))
	engine.started_dialogue.connect(func() -> void: _events.append("started_dialogue"))
	engine.finished_dialogue.connect(func() -> void: _events.append("finished_dialogue"))
	engine.entered_node.connect(
		func(node_id: String) -> void: _events.append("entered:" + node_id)
	)
	engine.line_service.executed_narration_line.connect(
		func(line: WeavlyModel.NarrationLine) -> void: _events.append("narration:" + line.text)
	)
	engine.line_service.executed_character_line.connect(
		func(line: WeavlyModel.CharacterLine) -> void: _events.append("character:" + line.text)
	)
	engine.option_service.options_added.connect(
		func(_options: Array[WeavlyModel.Option]) -> void: _events.append("options_added")
	)
	engine.command_service.executed_command.connect(
		func(command: WeavlyModel.CommandStatement) -> void:
			_events.append("command:" + command.id)
	)
	return engine


# Lines as their text, commands as id and values, option blocks as their option texts.
func _describe(entries: Array[WeavlyModel.Statement]) -> Array:
	var described: Array = []
	for entry: WeavlyModel.Statement in entries:
		if entry is WeavlyModel.LineStatement:
			described.append(entry.text)
		elif entry is WeavlyModel.CommandStatement:
			described.append([entry.id, entry.values])
		elif entry is WeavlyModel.OptionBlock:
			described.append(
				entry.options.map(func(option: WeavlyModel.Option) -> String: return option.text)
			)
	return described


func _option(entries: Array[WeavlyModel.Statement], text: String) -> WeavlyModel.Option:
	for entry: WeavlyModel.Statement in entries:
		if entry is WeavlyModel.OptionBlock:
			for option: WeavlyModel.Option in entry.options:
				if option.text == text:
					return option
	return null


# =====================
# render
# =====================


func test_render_returns_filled_lines_commands_and_option_blocks_in_order() -> void:
	var entries: Array[WeavlyModel.Statement] = _make_engine().render("tavern")
	(
		assert_array(_describe(entries))
		. is_equal(
			[
				"Welcome, you have 0 gold.",
				["header", ["Tavern", 1.0]],
				["Buy a drink", "Gamble (closed)"],
				"The fire crackles.",
				["Leave"],
				["Look around"],
			]
		)
	)
	assert_object(entries[0]).is_instanceof(WeavlyModel.CharacterLine)
	assert_that(entries[0].name).is_equal("Innkeeper")
	assert_bool(_option(entries, "Gamble (closed)").hint).is_true()


func test_render_changes_state_and_visits_like_normal_play() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.render("tavern")
	assert_that(engine.variable_service.get_variable("gold")).is_equal(5.0)
	assert_int(engine.node_service.get_visit_count("tavern")).is_equal(1)
	assert_bool(engine.is_running()).is_false()


func test_render_runs_no_option_action_and_hands_nothing_to_the_services() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.render("tavern")
	assert_that(engine.variable_service.get_variable("drinks")).is_equal(0.0)
	assert_bool(engine.variable_service.get_variable("left")).is_false()
	assert_array(_events).is_equal(["entered:tavern"])


func test_render_follows_a_goto() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entries: Array[WeavlyModel.Statement] = engine.render("lobby")
	assert_array(_events).is_equal(["entered:lobby", "entered:tavern"])
	assert_that(_describe(entries)[0]).is_equal("Welcome, you have 0 gold.")


func test_finish_ends_the_render() -> void:
	assert_array(_describe(_make_engine().render("stop"))).is_equal(["Before."])


func test_render_of_a_missing_node_is_reported() -> void:
	var engine: WeavlyEngine = _make_engine()
	assert_array(engine.render("nowhere")).is_empty()
	assert_logged(["Can't enter node 'nowhere' because it doesn't exist, finishing the dialogue."])
	assert_bool(engine.is_running()).is_false()


func test_render_during_a_dialogue_warns_and_does_nothing() -> void:
	var engine: WeavlyEngine = _make_engine()
	engine.start("bar")
	assert_array(engine.render("tavern")).is_empty()
	assert_logged([], ["Dialogue is already in progress, can't render node 'tavern'."])
	assert_int(engine.node_service.get_visit_count("tavern")).is_equal(0)
	assert_that(engine.current_node_id).is_equal("bar")


# =====================
# choose
# =====================


func test_choose_runs_only_the_action_and_ends_without_a_jump() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entries: Array[WeavlyModel.Statement] = engine.render("tavern")
	_events.clear()
	engine.choose(_option(entries, "Leave"))
	assert_bool(engine.variable_service.get_variable("left")).is_true()
	assert_that(engine.variable_service.get_variable("gold")).is_equal(5.0)
	assert_int(engine.node_service.get_visit_count("tavern")).is_equal(1)
	assert_array(_events).is_equal(["started_dialogue", "finished_dialogue"])


func test_choose_plays_on_into_the_node_a_jump_leads_to() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entries: Array[WeavlyModel.Statement] = engine.render("tavern")
	_events.clear()
	engine.choose(_option(entries, "Buy a drink"))
	assert_array(_events).is_equal(["started_dialogue", "narration:The drink is cold."])
	engine.next()
	assert_array(_events.slice(2)).is_equal(["entered:bar", "character:1 drinks so far."])
	assert_bool(engine.is_running()).is_true()


func test_choose_rejects_a_hint_and_an_option_that_was_not_rendered() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entries: Array[WeavlyModel.Statement] = engine.render("tavern")
	engine.choose(_option(entries, "Gamble (closed)"))
	var parsed: WeavlyModel.Option = engine.node_service.get_node("tavern").body[5].options[0]
	engine.choose(parsed)
	assert_logged(
		[],
		[
			"Can't choose option 'Gamble (closed)' because it's a hint.",
			"Can't choose option '' because it wasn't rendered.",
		]
	)
	assert_bool(engine.is_running()).is_false()
	assert_bool(engine.variable_service.get_variable("left")).is_false()


# =====================
# render_option
# =====================


func test_render_option_follows_a_jump_into_the_next_node() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entries: Array[WeavlyModel.Statement] = engine.render("tavern")
	var next_entries: Array[WeavlyModel.Statement] = engine.render_option(
		_option(entries, "Buy a drink")
	)
	assert_array(_describe(next_entries)).is_equal(
		["The drink is cold.", "1 drinks so far.", ["Another"]]
	)
	assert_bool(engine.is_running()).is_false()
	assert_int(engine.node_service.get_visit_count("bar")).is_equal(1)


func test_render_option_replaces_the_options_that_can_be_chosen() -> void:
	var engine: WeavlyEngine = _make_engine()
	var entries: Array[WeavlyModel.Statement] = engine.render("tavern")
	var next_entries: Array[WeavlyModel.Statement] = engine.render_option(
		_option(entries, "Buy a drink")
	)
	assert_array(engine.render_option(_option(entries, "Leave"))).is_empty()
	assert_logged([], ["Can't choose option 'Leave' because it wasn't rendered."])
	var again: Array[WeavlyModel.Statement] = engine.render_option(
		_option(next_entries, "Another")
	)
	assert_array(_describe(again)).is_equal(["1 drinks so far.", ["Another"]])


func test_options_of_several_renders_can_be_chosen() -> void:
	var engine: WeavlyEngine = _make_engine()
	var tavern: Array[WeavlyModel.Statement] = engine.render("tavern")
	engine.render("bar")
	engine.choose(_option(tavern, "Leave"))
	assert_bool(engine.variable_service.get_variable("left")).is_true()


# =====================
# Save and load
# =====================


func test_a_save_after_a_render_loads_without_starting_and_renders_the_same() -> void:
	var engine: WeavlyEngine = _make_engine()
	var rendered: Array = _describe(engine.render("lucky"))
	var gold: float = engine.variable_service.get_variable("gold")
	var state: Dictionary = JSON.parse_string(JSON.stringify(engine.get_state()))
	assert_that(state["node"]).is_equal("lucky")
	assert_bool(state["rendered"]).is_true()
	engine.render("lucky")
	_events.clear()
	engine.set_state(state)
	assert_array(_events).is_empty()
	assert_bool(engine.is_running()).is_false()
	assert_int(engine.node_service.get_visit_count("lucky")).is_equal(0)
	assert_array(_describe(engine.render("lucky"))).is_equal(rendered)
	assert_that(engine.variable_service.get_variable("gold")).is_equal(gold)
