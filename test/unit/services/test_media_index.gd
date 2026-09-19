extends WeavlyTestSuite

var _index: WeavlyMediaIndex


func before_test() -> void:
	_index = WeavlyMediaIndex.new("Image")


# =====================
# add / pick
# =====================


func test_add_and_pick() -> void:
	_index.add("splash", "res://splash.png")
	assert_str(_index.pick("splash")).is_equal("res://splash.png")


func test_pick_unknown_id_is_empty() -> void:
	assert_str(_index.pick("missing")).is_equal("")


func test_add_duplicate_is_ignored_and_warns() -> void:
	_index.add("splash", "res://a.png")
	_index.add("splash", "res://b.png")
	assert_str(_index.pick("splash")).is_equal("res://a.png")
	assert_logged([], ["Image with id 'splash' already exists."])


# =====================
# Grouping
# =====================


func test_group_pattern_collapses_ids_into_one_group() -> void:
	_index.set_group_pattern("_\\d+$")
	_index.add("idle_1", "res://idle_1.png")
	_index.add("idle_2", "res://idle_2.png")
	assert_array(_index.paths.keys()).contains_exactly(["idle"])
	assert_array(_index.paths["idle"]).contains_exactly(["res://idle_1.png", "res://idle_2.png"])


func test_group_pattern_keeps_unmatched_ids_as_single_entries() -> void:
	_index.set_group_pattern("_\\d+$")
	_index.add("splash", "res://splash.png")
	assert_str(_index.pick("splash")).is_equal("res://splash.png")


func test_group_pattern_allows_duplicate_ids_without_warning() -> void:
	_index.set_group_pattern("_\\d+$")
	_index.add("idle_1", "res://a.png")
	_index.add("idle_1", "res://b.png")
	assert_array(_index.paths["idle"]).has_size(2)


func test_empty_group_pattern_restores_single_entries() -> void:
	_index.set_group_pattern("_\\d+$")
	_index.set_group_pattern("")
	_index.add("idle_1", "res://idle_1.png")
	assert_str(_index.pick("idle_1")).is_equal("res://idle_1.png")


func test_invalid_group_pattern_falls_back_to_no_grouping() -> void:
	_index.set_group_pattern("[")
	_index.add("idle_1", "res://idle_1.png")
	assert_str(_index.pick("idle_1")).is_equal("res://idle_1.png")
	assert_logged(
		["missing terminating ]", "Failed to compile image group_pattern '[', falling back"]
	)
