extends WeavlyTestSuite

const FakeEngine = preload("res://test/helpers/fake_engine.gd")

var _engine: WeavlyEngine


func before_test() -> void:
	_engine = auto_free(FakeEngine.new())
	add_child(_engine)
	declare_variable(_engine, "name", "Ada")


func _block(text: Array, line: int) -> WeavlyModel.OptionBlock:
	var label: WeavlyModel.WeavlyExpression = WeavlyDeserializer.read_expression(
		{"text": text}, "test"
	)
	var body: Array[WeavlyModel.Statement] = []
	var item: WeavlyModel.InlineOptionItem = WeavlyModel.InlineOptionItem.new(
		WeavlyModel.TrueExpression.new(), label, body
	)
	item.line = line
	var items: Array[WeavlyModel.OptionItem] = [item]
	return WeavlyModel.OptionBlock.new(items)


func test_an_inline_option_is_offered_with_its_text_filled() -> void:
	_engine.current_source = "camp.wvl"
	var options: Array[WeavlyModel.Option] = WeavlyOptionBuilder.offer(
		_block(["Ask ", {"variable": "name"}], 6), _engine
	)
	assert_str(options[0].text).is_equal("Ask Ada")
	assert_int(options[0].line).is_equal(6)
	assert_str(options[0].source).is_equal("camp.wvl")
	assert_bool(options[0].is_choosable()).is_true()


func test_a_failing_interpolation_is_reported_at_the_option_line() -> void:
	var lines: Array[int] = []
	_engine.runtime_error.connect(
		func(_message: String, _source: String, line: int) -> void: lines.append(line)
	)
	WeavlyOptionBuilder.offer(_block([{"variable": "missing"}], 9), _engine)
	assert_array(lines).is_equal([9])
	assert_logged(["Variable 'missing' isn't defined."])


func test_an_unknown_node_is_reported_and_not_offered() -> void:
	assert_object(WeavlyOptionBuilder.offer_node(_engine, "nowhere")).is_null()
	assert_logged(["Can't offer node 'nowhere' because it doesn't exist."])
