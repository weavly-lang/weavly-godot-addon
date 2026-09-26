extends WeavlyTestSuite

var _list: WeavlyChoiceList
var _chosen: Array[String]


func before_test() -> void:
	_chosen = []
	_list = auto_free(WeavlyChoiceList.new())
	_list.chosen.connect(func(option: WeavlyModel.Option) -> void: _chosen.append(option.text))
	add_child(_list)


func _option(text: String, hint: bool = false) -> WeavlyModel.Option:
	var option: WeavlyModel.Option = WeavlyModel.Option.new(null, [text], [], hint)
	option.text = text
	return option


func _show(hints: Array[bool]) -> void:
	var options: Array[WeavlyModel.Option] = []
	for i: int in hints.size():
		options.append(_option("Option %d" % i, hints[i]))
	_list.show_options(options)


func test_shows_buttons_with_hints_disabled_and_unselectable() -> void:
	_show([false, true])
	var buttons: Array[Node] = _list.get_children()
	(
		assert_array(buttons.map(func(button: Button) -> String: return button.text))
		. is_equal(["Option 0", "Option 1"])
	)
	assert_bool(buttons[0].disabled).is_false()
	assert_int(buttons[0].focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool(buttons[1].disabled).is_true()
	assert_int(buttons[1].focus_mode).is_equal(Control.FOCUS_NONE)


func test_links_mode_shows_link_buttons() -> void:
	_list.links = true
	_show([false, true])
	assert_object(_list.get_child(0)).is_instanceof(LinkButton)
	assert_int(_list.get_child(1).underline).is_equal(LinkButton.UNDERLINE_MODE_NEVER)


func test_pressing_emits_the_option() -> void:
	_show([false, false])
	_list.get_child(1).pressed.emit()
	assert_array(_chosen).is_equal(["Option 1"])


func test_showing_again_replaces_the_options() -> void:
	_show([false, false])
	_show([false])
	assert_int(_list.get_child_count()).is_equal(1)


func test_has_choosable() -> void:
	_show([true])
	assert_bool(_list.has_choosable()).is_false()
	_show([true, false])
	assert_bool(_list.has_choosable()).is_true()


func test_focus_first_skips_hints() -> void:
	_show([true, false])
	assert_bool(_list.focus_first()).is_true()
	assert_bool(_list.get_child(1).has_focus()).is_true()


func test_focus_first_keeps_an_existing_selection() -> void:
	_show([false, false])
	_list.get_child(1).mouse_entered.emit()
	assert_bool(_list.focus_first()).is_false()
	assert_bool(_list.get_child(1).has_focus()).is_true()


func test_focus_first_without_choosable_options() -> void:
	_show([true])
	assert_bool(_list.focus_first()).is_false()


func test_clear_removes_every_option() -> void:
	_show([false, false])
	_list.clear()
	assert_int(_list.get_child_count()).is_equal(0)
