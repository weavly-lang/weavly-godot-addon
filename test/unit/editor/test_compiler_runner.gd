extends GutTest

const SYNTAX_ERROR_OUTPUT = """src/sub/broken.wvl:2:11: error: unexpected end of line
  2 | @set $x =
    |           ^
  expected one of: '$', '(', '-', 'false', 'not', 'true', a number, a quoted string
src/b.wvl:2:7: error: goto target 'nowhere' matches no node"""

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
	assert_eq(result.errors.size(), 0)


func test_build_result_failure_on_nonzero_exit() -> void:
	var result = WeavlyCompilerRunner.build_result(1, "boom")
	assert_false(result.success)


func test_build_result_parses_errors_on_failure() -> void:
	var result = WeavlyCompilerRunner.build_result(1, "src/story.wvl:12:4: error: boom")
	assert_eq(result.errors.size(), 1)


func test_build_result_strips_ansi_from_output() -> void:
	var esc = char(27)
	var result = WeavlyCompilerRunner.build_result(1, esc + "[31mboom" + esc + "[0m")
	assert_eq(result.output, "boom")


# =====================
# parse_errors
# =====================


func test_parse_errors_reads_file_line_column_and_message() -> void:
	var errors = WeavlyCompilerRunner.parse_errors("src/story.wvl:12:4: error: unexpected 'Go'")
	assert_eq(errors.size(), 1)
	assert_eq(errors[0].file, "src/story.wvl")
	assert_eq(errors[0].line, 12)
	assert_eq(errors[0].column, 4)
	assert_eq(errors[0].message, "unexpected 'Go'")


func test_parse_errors_without_column() -> void:
	var errors = WeavlyCompilerRunner.parse_errors(
		"src/d.wvl:2: error: invalid encoding, files must be saved as UTF-8"
	)
	assert_eq(errors.size(), 1)
	assert_eq(errors[0].line, 2)
	assert_eq(errors[0].column, -1)


func test_parse_errors_ignores_errors_without_location() -> void:
	var errors = WeavlyCompilerRunner.parse_errors("error: directory 'src' already exists")
	assert_eq(errors.size(), 0)


func test_parse_errors_collects_every_error_and_skips_detail_lines() -> void:
	var errors = WeavlyCompilerRunner.parse_errors(SYNTAX_ERROR_OUTPUT)
	assert_eq(errors.size(), 2)
	assert_eq(errors[0].file, "src/sub/broken.wvl")
	assert_eq(errors[0].line, 2)
	assert_eq(errors[0].column, 11)
	assert_eq(errors[0].message, "unexpected end of line")
	assert_eq(errors[1].file, "src/b.wvl")
	assert_eq(errors[1].message, "goto target 'nowhere' matches no node")


func test_parse_errors_handles_crlf_output() -> void:
	var errors = WeavlyCompilerRunner.parse_errors(SYNTAX_ERROR_OUTPUT.replace("\n", "\r\n"))
	assert_eq(errors.size(), 2)
	assert_eq(errors[0].message, "unexpected end of line")
	assert_eq(errors[1].column, 7)


func test_parse_errors_resolves_paths_against_working_dir() -> void:
	var errors = WeavlyCompilerRunner.parse_errors(
		"src/sub/a.wvl:1:1: error: boom", "C:/Games/My Project/dialog"
	)
	assert_eq(errors[0].file, "C:/Games/My Project/dialog/src/sub/a.wvl")
