@tool
extends RefCounted
## Inline before engine initialization, with no extra network request.
static func source() -> String:
	var config = preload("res://addons/game_base/project_config.gd").current()
	var result := "window.GodotBaseConfig = " + JSON.stringify(config.web_config()).replace("<", "\\u003c") + ";\n"
	for filename in ["loading_graphics.js", "loading_details.js", "loading_controller.js"]:
		var code := FileAccess.get_file_as_string("res://addons/game_base/web/" + filename)
		if code.is_empty() or "</script" in code: return ""
		result += code + "\n"
	return result
