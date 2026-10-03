extends CanvasLayer

var _status_key := "Loading..."
var _stage := -1
var _completed := 0
var _total := 0
var _web_boot: JavaScriptObject
var _detail: Dictionary = {}
var _began := Time.get_ticks_msec()
var _phase_began := 0
const PHASE_LABELS := {
	"audio_catalog": "Collecting sound resources", "audio": "Preparing sound samples",
	"hud_font": "Preparing HUD text", "damage_font": "Preparing damage text",
	"combat_effects": "Preparing combat effects", "ranged_effects": "Preparing projectile effects",
	"status_effects": "Preparing status effects", "world_materials": "Preparing world materials",
	"player_materials": "Preparing player materials", "weapon_effects": "Preparing weapon effects",
	"prop_fragments": "Loading prop fragments", "enemy_fragments": "Loading creature fragments",
	"fragment_materials": "Preparing fragment materials", "ui_effects": "Preparing interface effects",
	"light_states": "Preparing shaders", "render_resources": "Preparing lighting and effects..."}
const STAGES := ["resources", "scene", "systems", "graphics", "frame"]

const SafeArea = preload("res://addons/game_base/safe_area.gd")
@onready var surface: Control = $Surface
@onready var safe_area: MarginContainer = $Surface/SafeArea
@onready var status: Label = $Surface/SafeArea/Align/Panel/Rows/Status
@onready var progress: ProgressBar = $Surface/SafeArea/Align/Panel/Rows/Progress
@onready var retry: Button = $Surface/SafeArea/Align/Panel/Rows/Retry
@onready var detail_label: Label = $Surface/SafeArea/Align/Panel/Rows/Detail

func _ready() -> void:
	var config = preload("res://addons/game_base/project_config.gd").current()
	config.apply_loading($Surface/SafeArea/Align/Panel/Rows, $Surface/Background)
	if config.theme != null: surface.theme = config.theme
	if OS.has_feature("web"):
		_web_boot = JavaScriptBridge.get_interface("GodotBaseBoot")
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func update_stage(stage: String, value: float, message: String, completed := 0, total := 0) -> void:
	if stage != "graphics":
		_detail = {}
		detail_label.hide()
	progress.value = value * 100.0
	progress.show_percentage = true
	_status_key = message
	_stage = STAGES.find(stage)
	_completed = completed
	_total = total
	_refresh_status()
	if _web_boot != null: _web_boot.reportStage(stage, value, completed, total)

func update_warmup(detail: Dictionary) -> void:
	if _detail.get("phase", "") != detail.phase: _phase_began = Time.get_ticks_msec()
	_detail = detail.duplicate()
	update_stage("graphics", lerpf(0.80, 0.98, detail.ratio), PHASE_LABELS.get(detail.phase, detail.phase), detail.completed, detail.total)
	if _web_boot != null: _web_boot.reportDetail(JSON.stringify(detail))
	_refresh_detail()

func _process(_delta: float) -> void:
	if not _detail.is_empty(): _refresh_detail()

func _refresh_detail() -> void:
	detail_label.show()
	var elapsed := (Time.get_ticks_msec() - _began) / 1000.0
	var phase_time := (Time.get_ticks_msec() - _phase_began) / 1000.0
	detail_label.text = tr("Task %d / %d · Total %.1fs · Task %.1fs") % [_detail.phase_index, _detail.phase_total, elapsed, phase_time]
	if not str(_detail.item).is_empty(): detail_label.text += "\n" + str(_detail.item)

func _refresh_status() -> void:
	status.text = tr(_status_key)
	if _stage >= 0:
		status.text = "%d / %d · %s" % [_stage + 1, STAGES.size(), status.text]
	if _total > 0:
		status.text += " (%d%%)" % (_completed * 100 / _total) if _detail.get("phase", "") == "light_states" else " (%d/%d)" % [_completed, _total]

func complete() -> void:
	progress.value = 100.0
	if _web_boot != null: _web_boot.complete()

func show_failure() -> void:
	_status_key = "The game could not be loaded. Please try again."
	_stage = -1
	_completed = 0
	_total = 0
	status.text = tr(_status_key)
	progress.hide()
	retry.show()
	retry.grab_focus()
	if _web_boot != null: _web_boot.fail(status.text)

func _update_layout() -> void:
	SafeArea.apply(surface, safe_area)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh_status()
