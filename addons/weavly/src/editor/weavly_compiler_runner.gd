@tool
class_name WeavlyCompilerRunner
extends RefCounted

const ANSI_ESCAPE_PATTERN = "\\x1b\\[[0-9;]*m"
const ERROR_LOCATION_PATTERN = "(?m)^(\\S.*?):(\\d+)(?::(\\d+))?: error: (.*)$"


class CompileError:
	extends RefCounted

	var file: String = ""
	var line: int = -1
	var column: int = -1
	var message: String = ""


class CompileResult:
	extends RefCounted

	var success: bool = false
	var exit_code: int = -1
	var output: String = ""
	var errors: Array[CompileError] = []


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
	return build_result(exit_code, "".join(PackedStringArray(raw_output)), working_dir)


static func build_result(
	exit_code: int, raw_output: String, working_dir: String = ""
) -> CompileResult:
	var result: CompileResult = CompileResult.new()
	result.exit_code = exit_code
	result.output = strip_ansi(raw_output).strip_edges()
	result.success = exit_code == 0
	if not result.success:
		result.errors = parse_errors(result.output, working_dir)
	return result


static func strip_ansi(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile(ANSI_ESCAPE_PATTERN)
	return regex.sub(text, "", true)


static func parse_errors(output: String, working_dir: String = "") -> Array[CompileError]:
	var regex: RegEx = RegEx.new()
	regex.compile(ERROR_LOCATION_PATTERN)
	var errors: Array[CompileError] = []
	for found: RegExMatch in regex.search_all(output):
		var error: CompileError = CompileError.new()
		error.file = _resolve_path(found.get_string(1), working_dir)
		error.line = found.get_string(2).to_int()
		if found.get_string(3) != "":
			error.column = found.get_string(3).to_int()
		error.message = found.get_string(4).strip_edges()
		errors.append(error)
	return errors


static func _resolve_path(path: String, working_dir: String) -> String:
	if working_dir == "" or path.is_absolute_path():
		return path
	return working_dir.path_join(path).simplify_path()
