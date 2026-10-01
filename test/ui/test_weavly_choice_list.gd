extends WeavlyTestSuite

var _list: WeavlyChoiceList
var _chosen: Array[String]


func before_test() -> void:
	_chosen = []
	_list = auto_free(WeavlyChoiceList.new())
	_list.chosen.connect(func(option: WeavlyModel.Option) -> void: _chosen.append(option.text))
	add_child(_list)


func _option(text: String) -> WeavlyModel.Option:
	var option: WeavlyModel.Option = WeavlyModel.Option.new(null, [text], [])
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
