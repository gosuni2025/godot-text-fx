@tool
extends Resource
## Edit res://base_project.tres in the Inspector. No game/service defaults here.
@export_group("Identity")
@export var project_id := "my-game"
@export var title := "MY GAME"
@export var subtitle := ""
@export var tagline := ""
@export var loading_subtitle := ""
@export_group("Presentation")
@export var title_background: Texture2D
@export var loading_background: Texture2D
@export var theme: Theme
@export var accent := Color("c8a876")
@export var show_build := true
@export_range(0.5, 3.0) var title_size_multiplier := 1.8
@export var title_centered := true
@export_range(0.25, 2.0) var menu_size_multiplier := 0.5
@export_group("Title effect")
@export var title_material: ShaderMaterial = preload("res://addons/game_base/ui/title_material.tres")
@export_range(0.05, 10.0) var sweep_duration := 0.62
@export_range(0.0, 30.0) var sweep_delay := 0.45
@export_range(0.0, 30.0) var sweep_rest := 4.8
@export_group("Startup")
@export_file("*.tscn") var game_scene := ""
@export_file("*.gd") var warmup_script := ""
@export var show_loading_details := true
@export_group("Options")
## Each entry is an option_definition.gd resource; custom IDs emit settings.changed.
@export var options: Array[Resource] = []
@export_group("Manual profiling")
## Disabled until a project ID and an HTTPS endpoint are explicitly configured.
@export var profiler_enabled := false
@export var profiler_endpoint := ""

static func current() -> Resource:
	if ResourceLoader.exists("res://base_project.tres"):
		return load("res://base_project.tres")
	return load("res://addons/game_base/project_config.gd").new()

func web_config() -> Dictionary:
	return {"projectId": project_id, "title": title, "subtitle": loading_subtitle,
		"accent": "#" + accent.to_html(false), "showBuild": show_build,
		"showDetails": show_loading_details,
		"build": preload("res://addons/game_base/build_info.gd").version()}

func apply_title(rows: Node, background: TextureRect) -> void:
	rows.get_node("Title").text = title
	rows.get_node("Eyebrow").text = subtitle
	rows.get_node("Tagline").text = tagline
	for label in [rows.get_node("Eyebrow"), rows.get_node("Tagline")]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title_centered else HORIZONTAL_ALIGNMENT_LEFT
	if title_background != null: background.texture = title_background

func apply_loading(rows: Node, background: TextureRect) -> void:
	rows.get_node("Title").text = title
	rows.get_node("Eyebrow").text = loading_subtitle
	if loading_background != null: background.texture = loading_background
