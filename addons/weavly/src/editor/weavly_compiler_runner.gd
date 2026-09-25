@tool
class_name WeavlyCompilerRunner
extends RefCounted

const ANSI_ESCAPE_PATTERN = "\\x1b\\[[0-9;]*m"
const ERROR_LOCATION_PATTERN = "(?m)^(\\S.*?):(\\d+)(?::(\\d+))?: error: (.*)$"
const VERSION_PATTERN = "(?m)^weavly (\\d+)\\.(\\d+)\\.(\\d+)"
const MINIMUM_VERSION = "0.4.0"

static var _ansi_escape_regex: RegEx = RegEx.create_from_string(ANSI_ESCAPE_PATTERN)
static var _error_location_regex: RegEx = RegEx.create_from_string(ERROR_LOCATION_PATTERN)
static var _version_regex: RegEx = RegEx.create_from_string(VERSION_PATTERN)


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


static func build_version_command(executable_path: String) -> Dictionary:
	return _shell_command('"%s" --version' % executable_path)


# Empty when the executable is missing or --version fails.
static func get_version(executable_path: String) -> String:
	var command: Dictionary = build_version_command(executable_path)
	var raw_output: Array = []
	var exit_code: int = OS.execute(command["program"], command["arguments"], raw_output, true)
	if exit_code != 0:
		return ""
	return parse_version(strip_ansi("".join(PackedStringArray(raw_output))))


static func parse_version(output: String) -> String:
	var found: RegExMatch = _version_regex.search(output)
	if found == null:
		return ""
	return "%s.%s.%s" % [found.get_string(1), found.get_string(2), found.get_string(3)]


static func is_version_supported(version: String) -> bool:
	if version == "":
		return false
	var parts: PackedStringArray = version.split(".")
	var minimum: PackedStringArray = MINIMUM_VERSION.split(".")
	for i: int in minimum.size():
		var part: int = parts[i].to_int() if i < parts.size() else 0
		var required: int = minimum[i].to_int()
		if part != required:
			return part > required
	return true


static func build_command(executable_path: String, working_dir: String) -> Dictionary:
	var change_dir: String = "cd /d" if OS.get_name() == "Windows" else "cd"
	return _shell_command('%s "%s" && "%s" build' % [change_dir, working_dir, executable_path])


static func _shell_command(command_line: String) -> Dictionary:
	if OS.get_name() == "Windows":
		return {"program": "cmd", "arguments": PackedStringArray(["/c", command_line])}
	return {"program": "sh", "arguments": PackedStringArray(["-c", command_line])}


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
	return _ansi_escape_regex.sub(text, "", true)


static func parse_errors(output: String, working_dir: String = "") -> Array[CompileError]:
	var errors: Array[CompileError] = []
	for found: RegExMatch in _error_location_regex.search_all(output):
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
