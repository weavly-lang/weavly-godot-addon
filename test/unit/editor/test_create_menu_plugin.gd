extends GdUnitTestSuite

const CREATE_MENU = preload("res://addons/weavly/editor/weavly_create_menu_plugin.gd")


func test_a_new_file_names_its_node_after_the_file() -> void:
	assert_str(CREATE_MENU.node_name("res://dialogue/src/new_dialogue.wvl")).is_equal(
		"NewDialogue"
	)


func test_numbered_new_files_get_their_own_node() -> void:
	assert_str(CREATE_MENU.node_name("res://dialogue/src/new_dialogue_2.wvl")).is_equal(
		"NewDialogue2"
	)
