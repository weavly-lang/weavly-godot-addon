@tool
class_name WeavlyCompilerRunner
extends RefCounted

const ANSI_ESCAPE_PATTERN = "\\x1b\\[[0-9;]*m"
const ERROR_LOCATION_PATTERN = "Syntax Error in file: (.+?), Line (\\d+), Column (\\d+)"


class CompileResult:
	extends RefCounted

	var success: bool = false
	var exit_code: int = -1
	var output: String = ""
	var error_file: String = ""
	var error_line: int = -1
	var error_column: int = -1


static func build_command(executable_path: String, working_dir: String) -> Dictionary:
	if OS.get_name() == "Windows":
		var command_line: String = 'cd /d "%s" && "%s" build' % [working_dir, executable_path]
		return {"program": "cmd", "arguments": PackedStringArray(["/c", command_line])}

	var script: String = 'cd "%s" && "%s" build' % [working_dir, executable_path]
	return {"program": "sh", "arguments": PackedStringArray(["-c", script])}


static func compile(executable_path: String, working_dir: String) -> CompileResult:
	var command: Dictionary = build_command(executable_path, working_dir)
	var raw_output: Array = []
	var exit_code: int = OS.execute(command["program"], command["arguments"], raw_output, true)
	return build_result(exit_code, "".join(PackedStringArray(raw_output)))


static func build_result(exit_code: int, raw_output: String) -> CompileResult:
	var result: CompileResult = CompileResult.new()
	result.exit_code = exit_code
	result.output = strip_ansi(raw_output).strip_edges()
	result.success = exit_code == 0
	if not result.success:
		_parse_error_location(result)
	return result


static func strip_ansi(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile(ANSI_ESCAPE_PATTERN)
	return regex.sub(text, "", true)


static func _parse_error_location(result: CompileResult) -> void:
	var regex: RegEx = RegEx.new()
	regex.compile(ERROR_LOCATION_PATTERN)
	var found: RegExMatch = regex.search(result.output)
	if found == null:
		return
	result.error_file = found.get_string(1)
	result.error_line = found.get_string(2).to_int()
	result.error_column = found.get_string(3).to_int()
