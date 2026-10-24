extends RefCounted

const COMMANDS = ["env", "bash", "bwrap", "pasta", "nsenter", "steam"]


static func problem() -> String:
	if OS.get_name() != "Linux":
		return "Steam Co-op Play only runs on Linux."
	if FileAccess.file_exists("/.flatpak-info"):
		return "Steam Co-op Play can't sandbox Steam from a Flatpak Godot. Use the official Godot binary."
	var missing: Array[String] = []
	for command in COMMANDS:
		if OS.execute("bash", ["-c", "command -v " + command]) != 0:
			missing.append(command)
	if not missing.is_empty():
		return "Steam Co-op Play needs these commands installed: " + ", ".join(missing)
	return ""
