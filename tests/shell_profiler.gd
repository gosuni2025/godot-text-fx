extends RefCounted
## 운영 설정 연결과 비활성/잘못된 설정을 확인하고 앱 Source로 로컬 payload를 만든다.
## build_payload만 사용하며 운영 서버에 테스트 보고서를 전송하지 않는다.
const Reporter := preload("res://addons/web_profiler/performance_reporter.gd")
const ProfileConfig := preload("res://addons/web_profiler/profile_config.gd")
const ShellProfileSource := preload("res://app/shell/shell_profile_source.gd")
const ProjectConfig := preload("res://addons/game_base/project_config.gd")
const Shell := preload("res://app/shell/app_shell.gd")
const BuildInfo := preload("res://addons/game_base/build_info.gd")


func run(t) -> void:
	var shell: Node = t.tree.root.get_node_or_null("AppShell")
	if not t.ok(shell != null, "AppShell autoload exists"):
		return
	var config: Resource = ProjectConfig.current()
	t.eq(config.project_id, "godot-text-fx", "dedicated project ID")
	t.eq(config.profiler_endpoint, "https://dungeon-reign-profiler.gosuni2025.workers.dev/v1/reports", "shared upload endpoint")
	t.ok(config.profiler_enabled, "manual profiler enabled")
	if not t.ok(shell.profiler != null, "configured profiler connected by AppShell"):
		return
	t.eq(shell.profiler.config.project_id, config.project_id, "reporter uses configured ID")
	t.eq(shell.profiler.config.endpoint, config.profiler_endpoint, "reporter uses configured endpoint")
	shell.open_options()
	t.ok(shell.options.get_node("%Report").visible, "manual report button available")
	t.ok(shell.options.report_requested.is_connected(shell.send_profile_report), "manual upload action connected")
	shell.options.hide()
	shell.set_loading(true)
	t.ok(shell.profiler._loading, "boot loading suspends collection")
	shell.set_loading(false)
	await t.tree.process_frame
	var app_payload: Dictionary = shell.profiler.build_payload("profile")
	t.eq(app_payload.get("project"), config.project_id, "app payload uses registered project")
	t.eq(app_payload.get("build", {}).get("version"), BuildInfo.version(), "payload uses shared build stamp")
	t.eq(app_payload.get("context", {}).get("map_id"), "boot", "app source identifies boot without a scene")
	t.eq(shell.profiler.get_status().get("state"), "idle", "payload creation never uploads")
	t.eq(shell.profiler.get_status().get("attempts"), 0, "no upload attempts")

	var disconnected := Shell.new()
	var disabled: Resource = config.duplicate()
	disabled.profiler_enabled = false
	disconnected._setup_profiler(disabled)
	t.ok(disconnected.profiler == null, "disabled profiler stays unconnected")
	disabled.profiler_enabled = true
	disabled.profiler_endpoint = ""
	disconnected._setup_profiler(disabled)
	t.ok(disconnected.profiler == null, "empty endpoint stays unconnected")
	disconnected.free()

	var reporter := Reporter.new()
	t.tree.root.add_child(reporter)
	var invalid := ProfileConfig.new()
	invalid.project_id = "shell-test"
	t.ok(not reporter.bind_source(ShellProfileSource.new(shell), invalid), "empty endpoint refuses binding")
	var options := ProfileConfig.new()
	options.project_id = "shell-test"
	options.endpoint = "https://example.invalid/v1/reports"
	t.ok(reporter.bind_source(ShellProfileSource.new(shell), options), "valid config binds app source")
	await t.tree.process_frame
	var payload: Dictionary = reporter.build_payload("profile")
	t.eq(payload.get("project"), "shell-test", "payload project")
	t.ok(payload.has("window") and payload.has("counters"), "profile payload has window/counters")
	t.ok(str(payload.get("context", {}).get("map_id", "")) != "", "payload map_id from app source")
	t.eq(reporter.get_status().get("state", "idle"), "idle", "nothing sent")
	reporter.queue_free()
	await t.tree.process_frame
