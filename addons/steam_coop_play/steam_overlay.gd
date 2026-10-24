extends RefCounted

const LIBRARY = "ubuntu12_64/gameoverlayrenderer.so"
const LAYER_VARIABLE = "ENABLE_VK_LAYER_VALVE_steam_overlay_1"


static func environment_for(steam_root: String) -> Dictionary:
	var library := steam_root.path_join(LIBRARY)
	if not FileAccess.file_exists(library):
		return {}
	var preloads := OS.get_environment("LD_PRELOAD")
	return {
		"LD_PRELOAD": library if preloads.is_empty() else preloads + ":" + library,
		LAYER_VARIABLE: "1",
	}
