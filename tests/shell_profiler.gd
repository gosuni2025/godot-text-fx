extends RefCounted
## 프로파일러 연결: endpoint 미설정이면 연결하지 않고, 설정되면 앱 Source로 로컬 payload를 만든다.
## 네트워크 전송은 하지 않는다(테스트 endpoint는 build_payload만 사용).
const Reporter := preload("res://addons/web_profiler/performance_reporter.gd")
const ProfileConfig := preload("res://addons/web_profiler/profile_config.gd")
const ShellProfileSource := preload("res://app/shell/shell_profile_source.gd")
const ProjectConfig := preload("res://addons/game_base/project_config.gd")


func run(t) -> void:
	var shell: Node = t.tree.root.get_node_or_null("AppShell")
	if not t.ok(shell != null, "AppShell autoload exists"):
		return
	var config: Resource = ProjectConfig.current()
	t.eq(config.profiler_endpoint, "", "no endpoint configured for this project")
	t.ok(shell.profiler == null, "profiler stays unconnected without endpoint")

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
