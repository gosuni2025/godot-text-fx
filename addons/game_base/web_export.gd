@tool
extends EditorExportPlugin
## Base-only export. A host with its own export plugin calls web_bundle.source().
var _path := ""

func _get_name() -> String: return "GodotGameBase"

func _export_begin(features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
	_path = path if "web" in features and path.ends_with(".html") else ""

func _export_end() -> void:
	if _path.is_empty(): return
	var target := _path
	_path = ""
	var html := FileAccess.get_file_as_string(target)
	var source := preload("res://addons/game_base/web_bundle.gd").source()
	if "<!-- GODOT_BASE_LOADING -->" not in html or source.is_empty():
		push_error("Game Base requires its custom HTML shell and loading bundle")
		return
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write Game Base HTML: " + target)
		return
	file.store_string(html.replace("<!-- GODOT_BASE_LOADING -->", "<script>\n" + source + "\n</script>"))
