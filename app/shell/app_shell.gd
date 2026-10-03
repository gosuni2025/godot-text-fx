extends Node
## 앱 셸(autoload `AppShell`): game_base 설정 저장·적용, BGM, 공용 옵션 오버레이, 수동 프로파일러.
## 편집기 로직(app/logic)과 UI(app/editor)는 이 노드에 의존하지 않고, 화면 전환만 요청한다.
signal options_closed

const ProjectConfig = preload("res://addons/game_base/project_config.gd")
const SettingsStore = preload("res://addons/game_base/settings_store.gd")
const BuildInfo = preload("res://addons/game_base/build_info.gd")
const Reporter = preload("res://addons/web_profiler/performance_reporter.gd")
const ProfileConfig = preload("res://addons/web_profiler/profile_config.gd")
const ShellProfileSource = preload("res://app/shell/shell_profile_source.gd")

const SETTINGS_PATH := "user://settings.cfg"
const TITLE_SCENE := "res://app/shell/title_screen.tscn"
const EDITOR_SCENE := "res://app/editor/editor.tscn"
const LOCALES: PackedStringArray = ["ko", "ja", "en"]
const FALLBACK_LOCALE := "en"

var settings := SettingsStore.new()
var settings_error := OK
## 프로파일러가 설정되지 않으면 null이다(endpoint·project ID 미설정 시 연결하지 않음).
var profiler: Node
var _bgm_enabled := true
var _bgm_requested := false
var _options_in_game := false

@onready var bgm: AudioStreamPlayer = $Bgm
@onready var options: Control = $OptionsLayer/Options
@onready var build_label: Label = $OptionsLayer/Build

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ProjectConfig.current()
	settings.config_path = SETTINGS_PATH
	settings.changed.connect(apply_setting)
	if settings.configure(config.options) == OK:
		settings_error = settings.load_settings()
	else:
		push_error("AppShell: base_project.tres options are invalid")
		settings_error = ERR_INVALID_DATA
	build_label.text = BuildInfo.display_text()
	build_label.visible = false
	options.visibility_changed.connect(func(): build_label.visible = options.visible and config.show_build)
	options.closed.connect(func(): options_closed.emit())
	options.title_requested.connect(_on_title_requested)
	options.report_requested.connect(send_profile_report)
	_setup_profiler(config)

## settings_store.changed → 실제 엔진 설정. 실제 적용 코드가 있는 옵션만 base_project.tres에 노출한다.
func apply_setting(id: StringName, value: Variant) -> void:
	match id:
		&"fps_limit": Engine.max_fps = int(value)
		&"master_volume": _set_bus_volume(&"Master", float(value))
		&"bgm_volume": _set_bus_volume(&"BGM", float(value))
		&"sfx_volume": _set_bus_volume(&"SFX", float(value))
		&"bgm_enabled":
			_bgm_enabled = bool(value)
			_update_bgm()
		&"language":
			TranslationServer.set_locale(resolve_locale(str(value)))
			if build_label != null: build_label.text = BuildInfo.display_text()
			# 열린 옵션 행의 캡션은 bind 시점에 번역되므로 다시 만든다.
			if options != null and options.visible: _reopen_options.call_deferred()

static func resolve_locale(choice: String) -> String:
	if choice in LOCALES: return choice
	var system := OS.get_locale_language()
	return system if system in LOCALES else FALLBACK_LOCALE

func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0: return
	AudioServer.set_bus_mute(index, linear <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))

# --- BGM ---------------------------------------------------------------

## 타이틀·편집기에서 호출한다. 여러 번 호출해도 이어서 재생한다.
func play_bgm() -> void:
	_bgm_requested = true
	_update_bgm()

func stop_bgm() -> void:
	_bgm_requested = false
	_update_bgm()

func _update_bgm() -> void:
	if bgm == null: return
	if _bgm_requested and _bgm_enabled:
		if not bgm.playing: bgm.play()
	elif bgm.playing:
		bgm.stop()

# --- 화면 전환과 옵션 -------------------------------------------------

func go_to_title() -> void:
	options.hide()
	get_tree().change_scene_to_file(TITLE_SCENE)

func open_editor() -> void:
	if not ResourceLoader.exists(EDITOR_SCENE):
		push_error("AppShell: editor scene is missing: " + EDITOR_SCENE)
		return
	get_tree().change_scene_to_file(EDITOR_SCENE)

## in_game이면 System 탭의 "타이틀로 돌아가기"가 활성화된다(편집기에서 사용).
func open_options(in_game := false) -> void:
	_options_in_game = in_game
	options.open_menu(settings, in_game, profiler != null)

func _reopen_options() -> void:
	var tabs: TabBar = options.get_node("%Categories")
	var tab := tabs.current_tab
	options.open_menu(settings, _options_in_game, profiler != null)
	if tab >= 0 and tab < tabs.tab_count: tabs.current_tab = tab

func _on_title_requested() -> void:
	options.hide()
	options_closed.emit()
	go_to_title()

# --- 수동 프로파일링 ---------------------------------------------------

func _setup_profiler(config: Resource) -> void:
	var profile := ProfileConfig.new()
	profile.project_id = config.project_id if config.profiler_enabled else ""
	profile.endpoint = config.profiler_endpoint
	profile.measurement_schema_version = 1
	if not profile.is_valid(): return # endpoint 미설정: 연결하지 않는다.
	var reporter := Reporter.new()
	reporter.name = "PerformanceReporter"
	add_child(reporter)
	if not reporter.bind_source(ShellProfileSource.new(self), profile):
		reporter.queue_free()
		return
	profiler = reporter

## 부트 로딩 중에는 수집 구간을 나눈다. 프로파일러가 없으면 아무것도 하지 않는다.
func set_loading(value: bool) -> void:
	if profiler != null: profiler.set_loading(value)

## 옵션의 "Send profile" 버튼에서만 전송한다(자동 업로드 없음).
func send_profile_report() -> void:
	if profiler != null: profiler.send_report()
