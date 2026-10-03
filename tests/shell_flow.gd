extends RefCounted
## 부트(game_base 로딩) → 타이틀 → 편집기 → 타이틀 흐름을 헤드리스로 확인한다.
const BOOT := "res://app/shell/boot.tscn"
const TITLE := "res://app/shell/title_screen.tscn"
const EDITOR := "res://app/editor/editor.tscn"


func run(t) -> void:
	var tree: SceneTree = t.tree
	var shell: Node = tree.root.get_node_or_null("AppShell")
	if not t.ok(shell != null, "AppShell autoload exists"):
		return
	t.eq(ProjectSettings.get_setting("application/run/main_scene"), BOOT, "main scene is boot")
	t.eq(tree.change_scene_to_file(BOOT), OK, "boot scene loads")
	t.ok(await _wait_for(tree, TITLE, 600), "boot reaches title")
	if tree.current_scene == null or tree.current_scene.scene_file_path != TITLE:
		return
	var title: Control = tree.current_scene.get_node("Title")
	t.ok(title.get_node("%Build").text.length() > 0, "title shows build text")
	title.options_requested.emit()
	await tree.process_frame
	t.ok(shell.options.visible, "title opens shared options")
	t.ok(not shell.options.get_node("%ReturnTitle").visible or shell.options.get_node("%ReturnTitle").disabled, "return-to-title disabled on title")
	shell.options.get_node("%Back").pressed.emit()
	t.ok(not shell.options.visible, "back closes options")
	title.start_requested.emit()
	t.ok(await _wait_for(tree, EDITOR, 120), "start opens editor scene")
	shell.open_options(true)
	await tree.process_frame
	t.ok(not shell.options.get_node("%ReturnTitle").disabled, "return-to-title enabled in editor")
	shell.options.title_requested.emit()
	t.ok(await _wait_for(tree, TITLE, 120), "options return to title")
	t.ok(not shell.options.visible, "options hidden after returning")
	shell.stop_bgm()
	tree.unload_current_scene()
	await tree.process_frame


func _wait_for(tree: SceneTree, path: String, frames: int) -> bool:
	for i in frames:
		await tree.process_frame
		if tree.current_scene != null and tree.current_scene.scene_file_path == path:
			return true
	return false
