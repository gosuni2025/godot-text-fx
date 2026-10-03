@tool
extends EditorExportPlugin
const MARKER := "<!-- GODOT_WEB_PROFILER -->"
var _path := ""

func _get_name() -> String: return "GodotWebProfiler"

func _export_begin(features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
	_path = path if "web" in features and path.ends_with(".html") else ""

func _export_end() -> void:
	if _path.is_empty(): return
	var path := _path
	_path = ""
	var html := FileAccess.get_file_as_string(path)
	var source := preload("res://addons/web_profiler/web_bundle.gd").source()
	if MARKER not in html or source.is_empty():
		push_error("Web profiler needs " + MARKER + " before engine boot in the custom HTML shell")
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write profiler HTML: " + path)
		return
	file.store_string(html.replace(MARKER, "<script>\n" + source + "\n</script>"))
