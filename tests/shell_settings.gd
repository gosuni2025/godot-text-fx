extends RefCounted
## 앱 셸 옵션: base_project.tres 정의, 적용(프레임 제한·버스 음량·BGM·언어), 저장/재로드.
## 사용자 설정 파일(user://settings.cfg)은 건드리지 않고 별도 경로의 저장소로 검증한다.
const SettingsStore := preload("res://addons/game_base/settings_store.gd")
const ProjectConfig := preload("res://addons/game_base/project_config.gd")
const TEST_PATH := "user://test_shell_settings.cfg"
const EXPECTED_IDS := [&"fps_limit", &"master_volume", &"bgm_enabled", &"bgm_volume", &"sfx_volume", &"language"]


func run(t) -> void:
	var shell: Node = t.tree.root.get_node_or_null("AppShell")
	if not t.ok(shell != null, "AppShell autoload exists"):
		return
	var config: Resource = ProjectConfig.current()
	var ids: Array = config.options.map(func(entry): return entry.id)
	t.eq(ids, EXPECTED_IDS, "option ids (only options with apply code)")
	for entry in config.options:
		t.ok(entry.valid_definition(), "valid definition %s" % entry.id)
		# 콤보 리스트(OptionButton)는 언어 선택에만 남긴다.
		if entry.kind == 2: t.eq(entry.id, &"language", "only language is a choice option")
	t.eq(ProjectSettings.get_setting("application/config/custom_user_dir_name"), "godot-text-fx", "custom user dir")
	for bus in ["Master", "BGM", "SFX"]:
		t.ok(AudioServer.get_bus_index(bus) >= 0, "audio bus %s" % bus)
	t.eq(shell.bgm.bus, &"BGM", "BGM player on BGM bus")
	t.ok(shell.bgm.stream != null and shell.bgm.stream.loop, "BGM stream loops")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var store := SettingsStore.new()
	store.config_path = TEST_PATH
	store.changed.connect(shell.apply_setting)
	t.eq(store.configure(config.options), OK, "configure")
	t.eq(store.load_settings(), OK, "load defaults (missing file)")
	t.eq(Engine.max_fps, 60, "default frame limit 60")
	t.ok(TranslationServer.get_locale() in ["ko", "ja", "en"], "auto locale resolves to a UI locale")

	t.eq(store.set_value(&"fps_limit", 120.0), OK, "save fps 120")
	t.eq(Engine.max_fps, 120, "frame limit applied")
	t.eq(store.set_value(&"fps_limit", 45.0), OK, "range accepts in-bounds value")
	t.ne(store.set_value(&"fps_limit", 500.0), OK, "out-of-range fps rejected")
	t.eq(store.set_value(&"fps_limit", 120.0), OK, "save fps 120 again")

	store.set_value(&"master_volume", 0.5)
	t.near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")), linear_to_db(0.5), 0.01, "master volume dB")
	store.set_value(&"sfx_volume", 0.0)
	t.ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "sfx 0 mutes bus")
	store.set_value(&"bgm_volume", 0.25)
	t.near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), linear_to_db(0.25), 0.01, "bgm volume dB")

	store.set_value(&"bgm_enabled", false)
	shell.play_bgm()
	t.ok(not shell.bgm.playing, "BGM off keeps player stopped")
	store.set_value(&"bgm_enabled", true)
	t.ok(shell.bgm.playing, "BGM on starts player")
	shell.stop_bgm()
	t.ok(not shell.bgm.playing, "stop_bgm stops player")

	store.set_value(&"language", "ja")
	t.eq(TranslationServer.get_locale(), "ja", "locale ja")
	t.eq(TranslationServer.translate("Options"), "オプション", "ja translation")
	store.set_value(&"language", "en")
	t.eq(TranslationServer.translate("Start game"), "Start editing", "en translation")
	store.set_value(&"language", "ko")
	t.eq(TranslationServer.translate("Back"), "뒤로", "ko translation")

	var reloaded := SettingsStore.new()
	reloaded.config_path = TEST_PATH
	reloaded.configure(config.options)
	t.eq(reloaded.load_settings(), OK, "reload saved file")
	t.eq(reloaded.values[&"fps_limit"], 120.0, "fps persisted")
	t.eq(reloaded.values[&"language"], "ko", "language persisted")
	t.eq(reloaded.values[&"bgm_enabled"], true, "bgm toggle persisted")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	# 사용자 설정으로 되돌린다.
	shell.settings.load_settings()
	shell.stop_bgm()
