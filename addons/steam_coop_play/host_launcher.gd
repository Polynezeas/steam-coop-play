extends RefCounted

const LOOPBACK_HOSTS = ["127.0.0.1", "localhost", "::1"]
const EMBED_MODE_SETTING = "run/window_placement/game_embed_mode"
const EMBED_DISABLED = -1


static func play_main_scene(environment: Dictionary) -> void:
	var multiple_instances := _multiple_instances_checkbox()
	var multiple_instances_enabled := multiple_instances != null and multiple_instances.button_pressed
	if multiple_instances_enabled:
		multiple_instances.button_pressed = false
	var settings := EditorInterface.get_editor_settings()
	var embed_mode = settings.get_setting(EMBED_MODE_SETTING)
	settings.set_setting(EMBED_MODE_SETTING, EMBED_DISABLED)
	var previous_environment := _apply_environment(environment)
	EditorInterface.play_main_scene()
	_apply_environment(previous_environment)
	settings.set_setting(EMBED_MODE_SETTING, embed_mode)
	if multiple_instances_enabled:
		multiple_instances.button_pressed = true


static func debug_address(loopback_alias: String) -> String:
	var settings := EditorInterface.get_editor_settings()
	var host: String = settings.get_setting("network/debug/remote_host")
	if host in LOOPBACK_HOSTS:
		host = loopback_alias
	return "tcp://%s:%d" % [host, settings.get_setting("network/debug/remote_port")]


static func _multiple_instances_checkbox() -> CheckBox:
	for dialog in EditorInterface.get_base_control().find_children("*", "RunInstancesDialog", true, false):
		for checkbox in dialog.find_children("*", "CheckBox", true, false):
			return checkbox
	return null


static func _apply_environment(environment: Dictionary) -> Dictionary:
	var previous := {}
	for variable in environment:
		previous[variable] = OS.get_environment(variable) if OS.has_environment(variable) else null
		if environment[variable] == null:
			OS.unset_environment(variable)
		else:
			OS.set_environment(variable, environment[variable])
	return previous
