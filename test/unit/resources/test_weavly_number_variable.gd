extends GutTest


# =====================
# instantiate
# =====================


func test_no_min_no_max() -> void:
	var res := WeavlyNumberVariable.new()
	res.has_min = false
	res.has_max = false
	var v := res.instantiate()
	assert_null(v.min)
	assert_null(v.max)


func test_with_min() -> void:
	var res := WeavlyNumberVariable.new()
	res.has_min = true
	res.min = 5.0
	res.has_max = false
	var v := res.instantiate()
	assert_eq(v.min, 5.0)
	assert_null(v.max)


func test_with_max() -> void:
	var res := WeavlyNumberVariable.new()
	res.has_min = false
	res.has_max = true
	res.max = 10.0
	var v := res.instantiate()
	assert_null(v.min)
	assert_eq(v.max, 10.0)


func test_with_min_and_max() -> void:
	var res := WeavlyNumberVariable.new()
	res.has_min = true
	res.min = 1.0
	res.has_max = true
	res.max = 9.0
	var v := res.instantiate()
	assert_eq(v.min, 1.0)
	assert_eq(v.max, 9.0)


func test_value_is_passed_through() -> void:
	var res := WeavlyNumberVariable.new()
	res.value = 7.5
	var v := res.instantiate()
	assert_eq(v.value, 7.5)


func test_returns_number_variable() -> void:
	var v := WeavlyNumberVariable.new().instantiate()
	assert_is(v, WeavlyModel.NumberVariable)
