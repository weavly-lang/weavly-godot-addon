extends GutTest

# =====================
# build_command
# =====================


func _joined(command: Dictionary) -> String:
	return command["program"] + " " + " ".join(command["arguments"])


func test_build_command_references_executable_dir_and_verb() -> void:
	var command = WeavlyCompilerRunner.build_command("weavly", "/tmp/proj")
	var joined = _joined(command)
	assert_string_contains(joined, "weavly")
	assert_string_contains(joined, "/tmp/proj")
	assert_string_contains(joined, "build")


func test_build_command_program_matches_platform() -> void:
	var command = WeavlyCompilerRunner.build_command("weavly", "/tmp/proj")
	if OS.get_name() == "Windows":
		assert_eq(command["program"], "cmd")
	else:
		assert_eq(command["program"], "sh")


func test_build_command_quotes_paths_with_spaces() -> void:
	var command = WeavlyCompilerRunner.build_command(
		"C:/Program Files/weavly.exe", "C:/My Projects/dialog"
	)
	var joined = _joined(command)
	assert_string_contains(joined, '"C:/Program Files/weavly.exe"')
	assert_string_contains(joined, '"C:/My Projects/dialog"')


# =====================
# strip_ansi
# =====================


func test_strip_ansi_removes_color_codes() -> void:
	var esc = char(27)
	var raw = esc + "[31mSyntax Error" + esc + "[0m"
	assert_eq(WeavlyCompilerRunner.strip_ansi(raw), "Syntax Error")


func test_strip_ansi_leaves_plain_text_unchanged() -> void:
	assert_eq(WeavlyCompilerRunner.strip_ansi("plain text"), "plain text")


# =====================
# build_result
# =====================


func test_build_result_success_on_zero_exit() -> void:
	var result = WeavlyCompilerRunner.build_result(0, "Build successful")
	assert_true(result.success)
	assert_eq(result.error_line, -1)


func test_build_result_failure_on_nonzero_exit() -> void:
	var result = WeavlyCompilerRunner.build_result(1, "boom")
	assert_false(result.success)


func test_build_result_parses_error_location() -> void:
	var output = "Syntax Error in file: src/story.wvl, Line 12, Column 4\nUnexpected token"
	var result = WeavlyCompilerRunner.build_result(1, output)
	assert_eq(result.error_file, "src/story.wvl")
	assert_eq(result.error_line, 12)
	assert_eq(result.error_column, 4)


func test_build_result_strips_ansi_from_output() -> void:
	var esc = char(27)
	var result = WeavlyCompilerRunner.build_result(1, esc + "[31mboom" + esc + "[0m")
	assert_eq(result.output, "boom")
