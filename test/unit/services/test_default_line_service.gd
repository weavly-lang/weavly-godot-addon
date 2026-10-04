extends WeavlyTestSuite


func test_every_line_waits() -> void:
	var service: WeavlyDefaultLineService = WeavlyDefaultLineService.new()
	assert_bool(service.waits(WeavlyModel.NarrationLine.new(["hi"]))).is_true()
	assert_bool(service.waits(WeavlyModel.CharacterLine.new("Alice", false, ["hi"]))).is_true()
