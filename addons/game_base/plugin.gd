@tool
extends EditorPlugin
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = preload("res://addons/game_base/web_export.gd").new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
