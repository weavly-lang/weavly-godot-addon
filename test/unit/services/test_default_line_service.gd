extends WeavlyTestSuite


func test_every_line_waits() -> void:
	var service: WeavlyDefaultLineService = WeavlyDefaultLineService.new()
	assert_bool(service.waits(WeavlyModel.NarrationLine.new(["hi"]))).is_true()
	(
		assert_bool(
			service.waits(
				WeavlyModel.CharacterLine.new(WeavlyModel.StringLiteral.new("Alice"), ["hi"])
			)
		)
		. is_true()
	)
