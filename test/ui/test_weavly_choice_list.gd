extends WeavlyTestSuite

var _list: WeavlyChoiceList
var _chosen: Array[String]


func before_test() -> void:
	_chosen = []
	_list = auto_free(WeavlyChoiceList.new())
	_list.chosen.connect(func(option: WeavlyModel.Option) -> void: _chosen.append(option.text))
	add_child(_list)


func _option(text: String) -> WeavlyModel.Option:
	var option: WeavlyModel.Option = WeavlyModel.Option.new()
	option.text = text
	return option


func _show(count: int) -> void:
	var options: Array[WeavlyModel.Option] = []
	for i: int in count:
		options.append(_option("Option %d" % i))
	_list.show_options(options)


func test_shows_selectable_buttons() -> void:
	_show(2)
	var buttons: Array[Node] = _list.get_children()
	(
		assert_array(buttons.map(func(button: Button) -> String: return button.text))
		. is_equal(["Option 0", "Option 1"])
	)
	for button: Button in buttons:
		assert_bool(button.disabled).is_false()
		assert_int(button.focus_mode).is_equal(Control.FOCUS_ALL)


func test_links_mode_shows_link_buttons() -> void:
	_list.links = true
	_show(1)
	assert_object(_list.get_child(0)).is_instanceof(LinkButton)


func test_pressing_emits_the_option() -> void:
	_show(2)
	_list.get_child(1).pressed.emit()
	assert_array(_chosen).is_equal(["Option 1"])


func test_showing_again_replaces_the_options() -> void:
	_show(2)
	_show(1)
	assert_int(_list.get_child_count()).is_equal(1)


func test_has_choosable() -> void:
	_show(0)
	assert_bool(_list.has_choosable()).is_false()
	_show(1)
	assert_bool(_list.has_choosable()).is_true()


func test_focus_first_selects_the_first_option() -> void:
	_show(2)
	assert_bool(_list.focus_first()).is_true()
	assert_bool(_list.get_child(0).has_focus()).is_true()


func test_focus_first_keeps_an_existing_selection() -> void:
	_show(2)
	_list.get_child(1).mouse_entered.emit()
	assert_bool(_list.focus_first()).is_false()
	assert_bool(_list.get_child(1).has_focus()).is_true()


func test_focus_first_without_options() -> void:
	_show(0)
	assert_bool(_list.focus_first()).is_false()


func test_hovering_selects_an_option_until_the_mouse_leaves() -> void:
	_show(2)
	var button: Button = _list.get_child(0)
	button.mouse_entered.emit()
	assert_bool(button.has_focus()).is_true()
	button.mouse_exited.emit()
	assert_bool(button.has_focus()).is_false()


func test_leaving_an_option_keeps_a_selection_elsewhere() -> void:
	_show(2)
	_list.get_child(1).grab_focus()
	_list.get_child(0).mouse_exited.emit()
	assert_bool(_list.get_child(1).has_focus()).is_true()


func test_clear_removes_every_option() -> void:
	_show(2)
	_list.clear()
	assert_int(_list.get_child_count()).is_equal(0)


func _locked(text: String, state: WeavlyModel.Option.State) -> WeavlyModel.Option:
	var option: WeavlyModel.Option = _option(text)
	option.state = state
	return option


func _show_options(options: Array[WeavlyModel.Option]) -> void:
	_list.show_options(options)


func test_a_locked_option_shows_disabled_and_takes_no_focus() -> void:
	var options: Array[WeavlyModel.Option] = [
		_locked("Teased", WeavlyModel.Option.State.TEASER), _option("Open")
	]
	_show_options(options)
	var locked: Button = _list.get_child(0)
	assert_str(locked.text).is_equal("Teased")
	assert_bool(locked.disabled).is_true()
	assert_int(locked.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_bool(_list.focus_first()).is_true()
	assert_bool((_list.get_child(1) as Button).has_focus()).is_true()


func test_only_locked_options_have_nothing_choosable() -> void:
	var options: Array[WeavlyModel.Option] = [
		_locked("Poor", WeavlyModel.Option.State.UNAVAILABLE)
	]
	_show_options(options)
	assert_bool(_list.has_choosable()).is_false()
	assert_bool(_list.focus_first()).is_false()


func test_a_locked_link_has_no_underline() -> void:
	_list.links = true
	var options: Array[WeavlyModel.Option] = [
		_locked("Poor", WeavlyModel.Option.State.UNAVAILABLE)
	]
	_show_options(options)
	assert_int((_list.get_child(0) as LinkButton).underline).is_equal(
		LinkButton.UNDERLINE_MODE_NEVER
	)


func test_refresh_shows_the_current_text_and_state() -> void:
	var teased: WeavlyModel.Option = _locked("Teased", WeavlyModel.Option.State.TEASER)
	var open: WeavlyModel.Option = _option("Open")
	var options: Array[WeavlyModel.Option] = [teased, open]
	_show_options(options)
	(_list.get_child(1) as Button).grab_focus()
	teased.state = WeavlyModel.Option.State.AVAILABLE
	teased.text = "Hack"
	open.hidden = true
	_list.refresh()
	var first: Button = _list.get_child(0)
	assert_str(first.text).is_equal("Hack")
	assert_bool(first.disabled).is_false()
	assert_bool((_list.get_child(1) as Button).visible).is_false()
	assert_bool((_list.get_child(1) as Button).has_focus()).is_false()


func test_hovering_a_locked_option_doesnt_select_it() -> void:
	var options: Array[WeavlyModel.Option] = [
		_locked("Poor", WeavlyModel.Option.State.UNAVAILABLE)
	]
	_show_options(options)
	(_list.get_child(0) as Button).mouse_entered.emit()
	assert_bool(_list.has_focus_inside()).is_false()
