@tool
extends EditorPlugin

const SANDBOX_ROOT_SETTING = "plugins/steam_coop_play/sandbox_root"
const SANDBOX_SCRIPT_NAME = "steam_sandbox.sh"
const ICON_NAME = "icon.svg"
const STEAM_PID_FILE = "home/.steam/steam.pid"
const CONNECTION_LOG = "home/.local/share/Steam/logs/connection_log.txt"
const REQUIRED_COMMANDS = ["bash", "bwrap", "pasta", "nsenter", "steam"]
const LOG_TAIL_BYTES = 16384
const LOGIN_STATE_PATTERN = "^\\[[^\\]]*\\] \\[([A-Za-z ]+),"
const POLL_INTERVAL = 1.0

enum State { IDLE, WAITING_FOR_STEAM, RUNNING }

var _button: Button
var _state := State.IDLE
var _game_pid := -1
var _poll_timer := 0.0


func _enter_tree() -> void:
	_register_settings()
	_button = Button.new()
	_button.flat = true
	_button.toggle_mode = true
	_button.icon = _toolbar_icon()
	_button.pressed.connect(_on_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)
	_change_state(State.IDLE)


func _exit_tree() -> void:
	_stop_game()
	remove_control_from_container(CONTAINER_TOOLBAR, _button)
	_button.queue_free()


func _process(delta: float) -> void:
	_poll_timer -= delta
	if _poll_timer > 0.0:
		return
	_poll_timer = POLL_INTERVAL
	match _state:
		State.WAITING_FOR_STEAM:
			if _sandbox_steam_logged_on():
				_launch()
		State.RUNNING:
			if not EditorInterface.is_playing_scene():
				_stop_game()
				_change_state(State.IDLE)


func _on_pressed() -> void:
	match _state:
		State.IDLE:
			if not _can_run():
				return
			OS.set_environment("STEAM_SANDBOX_ROOT", _sandbox_root())
			if _sandbox_steam_logged_on():
				_launch()
				return
			if not _sandbox_steam_running():
				OS.create_process("bash", [_sandbox_script(), "steam"])
			_change_state(State.WAITING_FOR_STEAM)
		State.WAITING_FOR_STEAM:
			_change_state(State.IDLE)
		State.RUNNING:
			EditorInterface.stop_playing_scene()
			_stop_game()
			_change_state(State.IDLE)


func _launch() -> void:
	var multiple_instances := _multiple_instances_checkbox()
	var multiple_instances_enabled := multiple_instances != null and multiple_instances.button_pressed
	if multiple_instances_enabled:
		multiple_instances.button_pressed = false
	EditorInterface.play_main_scene()
	if multiple_instances_enabled:
		multiple_instances.button_pressed = true
	var settings := EditorInterface.get_editor_settings()
	var debug_address := "tcp://%s:%d" % [
		settings.get_setting("network/debug/remote_host"),
		settings.get_setting("network/debug/remote_port"),
	]
	_game_pid = OS.create_process("bash", [
		_sandbox_script(),
		"run",
		OS.get_executable_path(),
		"--path", ProjectSettings.globalize_path("res://"),
		"--remote-debug", debug_address,
	])
	_change_state(State.RUNNING)


func _register_settings() -> void:
	var settings := EditorInterface.get_editor_settings()
	var default_root := OS.get_data_dir().path_join("godot/steam_coop_play")
	if not settings.has_setting(SANDBOX_ROOT_SETTING):
		settings.set_setting(SANDBOX_ROOT_SETTING, default_root)
	settings.set_initial_value(SANDBOX_ROOT_SETTING, default_root, false)
	settings.add_property_info({
		"name": SANDBOX_ROOT_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
	})


func _can_run() -> bool:
	if OS.get_name() != "Linux":
		_report("Steam Co-op Play only runs on Linux.")
		return false
	if FileAccess.file_exists("/.flatpak-info"):
		_report("Steam Co-op Play can't sandbox Steam from a Flatpak Godot. Use the official Godot binary.")
		return false
	var missing: Array[String] = []
	for command in REQUIRED_COMMANDS:
		if OS.execute("bash", ["-c", "command -v " + command]) != 0:
			missing.append(command)
	if not missing.is_empty():
		_report("Steam Co-op Play needs these commands installed: " + ", ".join(missing))
		return false
	return true


func _report(message: String) -> void:
	EditorInterface.get_editor_toaster().push_toast(message, EditorToaster.SEVERITY_ERROR)


func _sandbox_root() -> String:
	return EditorInterface.get_editor_settings().get_setting(SANDBOX_ROOT_SETTING)


func _sandbox_script() -> String:
	return ProjectSettings.globalize_path(_plugin_dir().path_join(SANDBOX_SCRIPT_NAME))


func _plugin_dir() -> String:
	return get_script().resource_path.get_base_dir()


func _toolbar_icon() -> Texture2D:
	var svg := FileAccess.get_file_as_string(_plugin_dir().path_join(ICON_NAME))
	var image := Image.new()
	image.load_svg_from_string(svg, EditorInterface.get_editor_scale())
	return ImageTexture.create_from_image(image)


func _multiple_instances_checkbox() -> CheckBox:
	for dialog in EditorInterface.get_base_control().find_children("*", "RunInstancesDialog", true, false):
		for checkbox in dialog.find_children("*", "CheckBox", true, false):
			return checkbox
	return null


func _stop_game() -> void:
	if _game_pid > 0 and OS.is_process_running(_game_pid):
		OS.kill(_game_pid)
	_game_pid = -1


func _sandbox_steam_running() -> bool:
	var pid := FileAccess.get_file_as_string(_sandbox_root().path_join(STEAM_PID_FILE)).strip_edges()
	return pid.is_valid_int() and DirAccess.dir_exists_absolute("/proc/" + pid)


func _sandbox_steam_logged_on() -> bool:
	if not _sandbox_steam_running():
		return false
	var connection_log := FileAccess.open(_sandbox_root().path_join(CONNECTION_LOG), FileAccess.READ)
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


func _change_state(state: State) -> void:
	_state = state
	_button.set_pressed_no_signal(state != State.IDLE)
	match state:
		State.IDLE:
			_button.text = ""
			_button.tooltip_text = "Play with two Steam instances"
		State.WAITING_FOR_STEAM:
			_button.text = "Waiting for Steam…"
			_button.tooltip_text = "Log in to the sandboxed Steam client. Press to cancel."
		State.RUNNING:
			_button.text = ""
			_button.tooltip_text = "Stop both Steam instances"
