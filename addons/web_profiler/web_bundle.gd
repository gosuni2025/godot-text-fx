@tool
extends RefCounted
## Include before the engine script/startGame. Bundle inline so no runtime fetch is needed.
const HELPERS := ["frame_timing", "shader_provenance", "native_call_timing", "gpu_timing"]

static func source(shader_directory: String = "res://shaders", detailed_webgl := false) -> String:
	var catalog := preload("res://addons/web_profiler/shader_catalog.gd").build(shader_directory)
	var result := "window.GodotProfilerShaderCatalog = " + JSON.stringify(catalog).replace("<", "\\u003c") + ";\n"
	var helpers := ["frame_timing", "render_profiler", "gpu_timing"] if detailed_webgl else HELPERS
	for helper in helpers:
		var path: String = "res://addons/web_profiler/web/" + helper + ".js"
		var code := FileAccess.get_file_as_string(path)
		if code.is_empty() or "</script" in code: return ""
		result += code + "\n"
	return result
