@tool
extends EditorPlugin

const SANDBOX_STEAM = preload("sandbox_steam.gd")
const STEAM_OVERLAY = preload("steam_overlay.gd")
const HOST_LAUNCHER = preload("host_launcher.gd")
const REQUIREMENTS = preload("requirements.gd")
const SANDBOX_ROOT_SETTING = "plugins/steam_coop_play/sandbox_root"
const SECOND_OVERLAY_SETTING = "plugins/steam_coop_play/overlay_in_second_instance"
const HOST_STEAM_ROOT = ".steam/root"
const ICON_NAME = "icon.svg"
const POLL_INTERVAL = 1.0
const APP_ID_SETTINGS = ["steam/initialization/app_data/app_id", "steam/initialization/app_id"]

enum State { IDLE, WAITING_FOR_STEAM, RUNNING }

var _button: Button
var _state := State.IDLE
var _sandbox = null
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
			if _sandbox.is_logged_on():
				_launch()
		State.RUNNING:
			if not EditorInterface.is_playing_scene():
				_stop_game()
				_change_state(State.IDLE)


func _on_pressed() -> void:
	match _state:
		State.IDLE:
			var problem := REQUIREMENTS.problem()
			if not problem.is_empty():
				EditorInterface.get_editor_toaster().push_toast(problem, EditorToaster.SEVERITY_ERROR)
				_change_state(State.IDLE)
				return
			_sandbox = SANDBOX_STEAM.new(_sandbox_root())
			if _sandbox.is_logged_on():
				_launch()
				return
			if not _sandbox.is_running():
				_sandbox.start()
			_change_state(State.WAITING_FOR_STEAM)
		State.WAITING_FOR_STEAM:
			_change_state(State.IDLE)
		State.RUNNING:
			EditorInterface.stop_playing_scene()
			_stop_game()
			_change_state(State.IDLE)


func _launch() -> void:
	var app_id := _app_id()
	if app_id <= 0:
		EditorInterface.get_editor_toaster().push_toast(
				"Set the App ID in Project Settings → Steam → Initialization. Without it the Steam overlay can freeze the game.",
				EditorToaster.SEVERITY_WARNING)
	HOST_LAUNCHER.play_main_scene(
			STEAM_OVERLAY.environment_for(OS.get_environment("HOME").path_join(HOST_STEAM_ROOT), app_id))
	var command: Array[String] = [
		OS.get_executable_path(),
		"--path", ProjectSettings.globalize_path("res://"),
		"--remote-debug", HOST_LAUNCHER.debug_address(SANDBOX_STEAM.HOST_ADDRESS),
	]
	var sandbox_environment := {}
	if EditorInterface.get_editor_settings().get_setting(SECOND_OVERLAY_SETTING):
		sandbox_environment = STEAM_OVERLAY.environment_for(_sandbox.steam_root(), app_id)
	_game_pid = _sandbox.run(command, sandbox_environment)
	_change_state(State.RUNNING)


func _app_id() -> int:
	for setting in APP_ID_SETTINGS:
		var app_id := int(ProjectSettings.get_setting(setting, 0))
		if app_id > 0:
			return app_id
	return 0


func _stop_game() -> void:
	if _game_pid > 0 and OS.is_process_running(_game_pid):
		OS.kill(_game_pid)
	_game_pid = -1


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
	if not settings.has_setting(SECOND_OVERLAY_SETTING):
		settings.set_setting(SECOND_OVERLAY_SETTING, false)
	settings.set_initial_value(SECOND_OVERLAY_SETTING, false, false)
	settings.add_property_info({
		"name": SECOND_OVERLAY_SETTING,
		"type": TYPE_BOOL,
	})


func _sandbox_root() -> String:
	return EditorInterface.get_editor_settings().get_setting(SANDBOX_ROOT_SETTING)


func _toolbar_icon() -> Texture2D:
	var svg := FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join(ICON_NAME))
	var image := Image.new()
	image.load_svg_from_string(svg, EditorInterface.get_editor_scale())
	return ImageTexture.create_from_image(image)


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
