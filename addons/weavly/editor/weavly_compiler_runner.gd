@tool
class_name WeavlyCompilerRunner
extends RefCounted

const ANSI_ESCAPE_PATTERN = "\\x1b\\[[0-9;]*m"
const LOCATION_PATTERN = "(?m)^(\\S.*?):(\\d+)(?::(\\d+))?: %s: (.*)$"
const VERSION_PATTERN = "(?m)^weavly (\\d+)\\.(\\d+)\\.(\\d+)"
# In 0.x a minor release can change the output, so only this one is accepted.
const SUPPORTED_VERSION = "0.6"
const SOURCE_DIR = "src"

static var _ansi_escape_regex: RegEx = RegEx.create_from_string(ANSI_ESCAPE_PATTERN)
static var _error_location_regex: RegEx = RegEx.create_from_string(LOCATION_PATTERN % "error")
static var _warning_location_regex: RegEx = RegEx.create_from_string(LOCATION_PATTERN % "warning")
static var _version_regex: RegEx = RegEx.create_from_string(VERSION_PATTERN)


class CompileMessage:
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
	var errors: Array[CompileMessage] = []
	var warnings: Array[CompileMessage] = []


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
	return version.begins_with(SUPPORTED_VERSION + ".")


# The folder weavly build runs in: the parent of the nearest src folder above the file.
# Empty when the file isn't in a Weavly project.
static func project_dir_of(path: String) -> String:
	var dir: String = path.simplify_path().get_base_dir()
	while dir.get_file() != "":
		if dir.get_file() == SOURCE_DIR:
			return dir.get_base_dir()
		dir = dir.get_base_dir()
	return ""


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
	if result.success:
		result.warnings = parse_warnings(result.output, working_dir)
	else:
		result.errors = parse_errors(result.output, working_dir)
	return result


static func strip_ansi(text: String) -> String:
	return _ansi_escape_regex.sub(text, "", true)


static func parse_errors(output: String, working_dir: String = "") -> Array[CompileMessage]:
	return _parse_messages(_error_location_regex, output, working_dir)


static func parse_warnings(output: String, working_dir: String = "") -> Array[CompileMessage]:
	return _parse_messages(_warning_location_regex, output, working_dir)


static func is_warning(line: String) -> bool:
	return _warning_location_regex.search(line) != null


static func _parse_messages(
	regex: RegEx, output: String, working_dir: String
) -> Array[CompileMessage]:
	var messages: Array[CompileMessage] = []
	for found: RegExMatch in regex.search_all(output):
		var message: CompileMessage = CompileMessage.new()
		message.file = _resolve_path(found.get_string(1), working_dir)
		message.line = found.get_string(2).to_int()
		if found.get_string(3) != "":
			message.column = found.get_string(3).to_int()
		message.message = found.get_string(4).strip_edges()
		messages.append(message)
	return messages


static func _resolve_path(path: String, working_dir: String) -> String:
	if working_dir == "" or path.is_absolute_path():
		return path
	return working_dir.path_join(path).simplify_path()
