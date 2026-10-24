extends RefCounted

const SCRIPT_NAME = "steam_sandbox.sh"
const STEAM_ROOT = "home/.steam/root"
const STEAM_PID_FILE = "home/.steam/steam.pid"
const CONNECTION_LOG = "home/.local/share/Steam/logs/connection_log.txt"
const LOG_TAIL_BYTES = 16384
const LOGIN_STATE_PATTERN = "^\\[[^\\]]*\\] \\[([A-Za-z ]+),"
const HOST_ADDRESS = "169.254.1.2"

var root: String
var _script_path: String


func _init(sandbox_root: String) -> void:
	root = sandbox_root
	_script_path = ProjectSettings.globalize_path(
			get_script().resource_path.get_base_dir().path_join(SCRIPT_NAME))


func steam_root() -> String:
	return root.path_join(STEAM_ROOT)


func start() -> void:
	_execute(["steam"])


func run(command: Array[String], environment: Dictionary) -> int:
	var arguments: Array[String] = ["run", "env"]
	for variable in environment:
		arguments.append("%s=%s" % [variable, environment[variable]])
	arguments.append_array(command)
	return _execute(arguments)


func is_running() -> bool:
	var pid := FileAccess.get_file_as_string(root.path_join(STEAM_PID_FILE)).strip_edges()
	return pid.is_valid_int() and DirAccess.dir_exists_absolute("/proc/" + pid)


func is_logged_on() -> bool:
	if not is_running():
		return false
	var connection_log := FileAccess.open(root.path_join(CONNECTION_LOG), FileAccess.READ)
	if connection_log == null:
		return false
	connection_log.seek(maxi(connection_log.get_length() - LOG_TAIL_BYTES, 0))
	var lines := connection_log.get_buffer(LOG_TAIL_BYTES).get_string_from_utf8().split("\n")
	var login_state := RegEx.create_from_string(LOGIN_STATE_PATTERN)
	for i in range(lines.size() - 1, -1, -1):
		var found := login_state.search(lines[i])
		if found != null:
			return found.get_string(1) == "Logged On"
	return false


func _execute(arguments: Array[String]) -> int:
	var command: Array[String] = [
		"STEAM_SANDBOX_ROOT=" + root,
		"STEAM_SANDBOX_HOST_ADDRESS=" + HOST_ADDRESS,
		"bash", _script_path,
	]
	command.append_array(arguments)
	return OS.create_process("env", command)
